"""Prefabs drawn from Quake II's jail5, the Guard House: a courtyard under
the sky round a fountain, cells along it and a wall-walk over it; a
battlement walked over a passage inside the wall; the barracks of bunks
under a gallery; a trench of live water the guard booth shuts off; an
armory whose cases break; the pyramid key at the top of the captain's
tower. Raised in jail5's own palette.

- `GuardCourtyard`: the start. A courtyard round a fountain, the guard
  house's porch up steps, cells along one side barred by bars their
  buttons open, a wall-walk along the other up a lift called down. The help
  computer gives the objective; guards appear on the wall-walk as the
  player reaches the fountain.
- `Battlement`: a wall under the sky between two towers, its top walked
  from one tower's stair to the other's, a passage through the wall's
  inside below it (a loop); a ditch of spikes at its foot hurts; snipers
  appear on the far tower.
- `Barracks`: a hall of bunks under a gallery up a stair (or a lift),
  lockers that break open, guards asleep in their bunks woken as the
  player comes in. Ways on from the floor and the gallery (a hub).
- `PowerTrench`: a trench of water across the room, live with current,
  under a bridge (fixed, or drawn out from the booth); the booth over the
  near end, up a stair, shuts the current off; wires spark along it.
- `Armory`: a hall with a gallery round three sides, weapon cases along
  its walls behind glass that breaks; breaking one raises the alarm:
  charges go off and guards come. A panel by a broken console is live.
- `CaptainQuarters`: the key room. The pyramid key on top of the captain's
  tower up a stair winding round it; taking it blows open the closets
  along the near wall, charges going off.
- `GuardExit`: the end. A door (a key's, as a gate) out to a yard, the
  way out on a dais up steps; a fire pit beside it; guards appear as the
  player comes out."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, spiral, boulders, apart }
import from .warejail_parts { shutter, auto_shutters, key_cue, sparking, guards, charges, stash, keep_row, called_lift, closets, gate_pair, post_button, laser, bars, drip, hurt, merlons }

glob JAIL5: str = "q2:jail5";

"""jail5's foes: soldiers and flyers, mutants and a tank deeper in."""
def jail5_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_flyer";
    }
    return q1_foe(dice, q1_palette(["monster_soldier_ss", "monster_mutant"] if heavy else ["monster_soldier", "monster_soldier_ss", "monster_soldier_light"], ["monster_tank"] if heavy else ["monster_mutant", "monster_infantry"], danger * 0.5 if heavy else danger));
}

"""`count` of jail5's foes, the first heavy when `heavy`."""
def jail5_foes(dice: Stream, danger: float, count: int, heavy: bool = False) -> list[str] {
    return [jail5_foe(dice, danger, heavy and index == 0) for index in range(count)];
}

"""Crates heaped about a floor (the box x0..x1, y0..y1 on lift `z`): `count`
stacks two cells square, one to three lifts high, clear of `clear`."""
def crate_heaps(build: Raising, dice: Stream, x0: int, y0: int, x1: int, y1: int, z: int, count: int, clear: list[list[int]]) {
    placed: list[list[int]] = [];
    for index in range(count * 3) {
        if len(placed) >= count {
            break;
        }
        x = dice.between(x0, max(x0, x1 - 2));
        y = dice.between(y0, max(y0, y1 - 2));
        box = [x, y, x + 2, y + 2];
        if apart(box, clear) and apart(box, placed) {
            build.solid(x, y, z, x + 2, y + 2, z + dice.between(1, 3));
            placed.append(box);
        }
    }
}

"""The start: a courtyard round a fountain, the porch, cells, a wall-walk."""
node GuardCourtyard(Prefab) {
    has porch: int = 3,
        walk: int = 10,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Guard courtyard";
        self.source = JAIL5;
        self.district = level_district(JAIL5);
        self.long = dice.between(28, 31);
        self.wide = dice.between(22, 24);
        self.porch = dice.between(3, 4);
        self.walk = dice.between(12, 14);
        self.tall = self.walk + 12;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=self.porch),
            Port(face=1, along=float(self.long - 4), floor=self.porch),
            Port(face=1, along=7.0, floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        p = self.porch;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, p);
        build.level(yard, self.walk);
        # The guard house's porch across the far end, steps up its middle.
        px = self.long - 7;
        build.solid(px, 1, 0, self.long - 1, self.wide - 1, p);
        stair(build, px - p, middle - 2, 0, 0, p, 4);
        # The fountain in the yard: a basin a lift high, water in it, a
        # statue in the middle.
        cx = px // 2 + 1;
        build.solid(cx - 3, middle - 3, 0, cx + 3, middle + 3, 1);
        build.pool(cx - 2, middle - 2, 0, cx + 2, middle + 2, 1, 2, True, False);
        build.solid(cx - 1, middle - 1, 0, cx, middle, 5);
        # Cells along the south wall, barred; each a button on its wall.
        walls = [x for x in range(4, px - 3, 4)];
        # The cells' roof, so nothing drops into one.
        if walls {
            build.solid(1, 1, 5, walls[-1] + 1, 4, 7);
        }
        for (index, x) in enumerate(walls) {
            build.solid(x, 1, 0, x + 1, 4, 7);
            if index > 0 and index % 2 == 1 {
                cell_bars = bars(build, float(x - 3), 4.0, 0.0, float(x), 5.0, 5.0);
                build.push(float(x) + 0.5, 4.0, 1.0, 1) +>:Fires:+> cell_bars;
                build.foe(float(x) - 1.5, 2.5, 0, jail5_foe(dice, self.danger), 90.0);
            }
        }
        # The wall-walk along the north wall, a slab over the yard, up a lift
        # called down at its near end.
        wy = self.wide - 5;
        build.solid(3, wy, self.walk - 1, px, self.wide - 1, self.walk);
        merlons(build, wy, 8, px - 1, self.walk);
        post_button(build, 7, wy - 4, 0, 0) +>:Fires:+> called_lift(build, 3, wy - 3, 6, wy, 0, self.walk);
        keep_row(build, yard, 2, wy, self.walk, 1, 6);
        # A watchtower on the walk's far end, up a stair along the wall.
        build.solid(px - 5, wy, self.walk, px - 1, self.wide - 1, self.walk + 5);
        stair(build, px - 10, self.wide - 4, self.walk, 0, 5, 3);
        guards(build, build.touch(3.0, float(wy), float(self.walk), 7.0, float(self.wide - 1), float(self.walk + 6)), [[float(px) - 3.0, float(self.wide) - 3.0]], self.walk + 5, jail5_foes(dice, self.danger, 1), 180.0);
        crate_heaps(build, dice, 6, 6, px - 2, wy - 1, 0, dice.between(3, 5), [[0, middle - 3, 5, middle + 3], [cx - 5, middle - 5, cx + 5, middle + 5], [px - p - 2, middle - 3, px, middle + 3], [2, wy - 5, 9, wy]]);
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        porch = build.touch(float(px - p), float(middle - 2), 0.0, float(px), float(middle + 2), 6.0);
        guards(build, porch, [[float(self.long) - 3.5, float(middle) + 4.5], [float(self.long) - 3.5, float(middle) - 4.5]], p, jail5_foes(dice, self.danger, 2), 180.0);
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Locate the pyramid key, then return");
        # At the fountain, guards appear on the wall-walk.
        fountain = build.touch(float(cx - 5), float(middle - 5), 0.0, float(cx - 3), float(middle + 5), 6.0);
        guards(build, fountain, [[float(cx) + 0.5, float(self.wide) - 3.0], [float(px) - 11.5, float(self.wide) - 3.0]], self.walk, jail5_foes(dice, self.danger, 2), 270.0);
        build.foe(float(cx) - 4.5, float(middle) - 4.5, 0, "monster_soldier", 0.0, patrol=[[float(cx) - 4.5, float(middle) - 4.5], [float(cx) + 4.5, float(middle) - 4.5], [float(cx) + 4.5, float(middle) + 4.5], [float(cx) - 4.5, float(middle) + 4.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * 5.0, p, jail5_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(cx) + 0.5, 8.5, 12, jail5_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(px) - 2.5, 7.5, 0, Q2_HEALTH, "q2");
    }
}

"""A wall under the sky between two towers, its top walked, a passage
through its inside below."""
node Battlement(Prefab) {
    has wall: int = 9,
        tall: int = 21;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Battlement";
        self.source = JAIL5;
        self.district = level_district(JAIL5);
        self.long = dice.between(29, 32);
        self.wall = dice.between(12, 14);
        # The yard deep enough that the stairs up start clear of the ditch.
        self.wide = self.wall + dice.between(12, 13);
        self.tall = self.wall + 12;
        self.low = -3;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [Port(face=0, along=4.0, floor=0), Port(face=0, along=float(self.wide - 3), floor=self.wall + 5), Port(face=1, along=float(self.long // 2), floor=self.wall)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        w = self.wall;
        ground = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(ground, w);
        wy = self.wide - 7;
        # The wall along the north side, its top walked, merlons on its outer
        # edge; a passage through its inside, three cells wide, open to the
        # yard at both ends.
        build.solid(1, wy, 0, self.long - 1, self.wide - 1, w);
        merlons(build, self.wide - 2, 9, self.long - 9, w);
        passage = build.room(7, wy + 2, 0, self.long - 7, wy + 5, 6);
        build.widen(passage, 8, wy, 0, 11, wy + 2, 6);
        build.widen(passage, self.long - 11, wy, 0, self.long - 8, wy + 2, 6);
        # Towers at both ends, a stair up each one's face to the walk.
        build.solid(1, wy - 3, 0, 6, wy, w + 4);
        build.solid(self.long - 6, wy - 3, 0, self.long - 1, wy, w + 4);
        # A tower on the wall's far end, up a stair along the walk.
        build.solid(self.long - 6, wy, w, self.long - 1, self.wide - 1, w + 5);
        stair(build, self.long - 11, wy, w, 0, 5, 3);
        stair(build, 12, wy - w, 0, 1, w, 3);
        stair(build, self.long - 15, wy - w, 0, 1, w, 3);
        keep_row(build, ground, 11, wy, w, 1, 5);
        keep_row(build, ground, self.long - 16, wy, w, 1, 5);
        # A ditch of spikes along the yard's far side, two lifts deep, a step
        # out at each end.
        dx0 = 8;
        dx1 = self.long - 8;
        build.room(dx0, 1, -2, dx1, 4, 0);
        build.solid(dx0, 1, -2, dx0 + 1, 4, -1);
        build.solid(dx1 - 1, 1, -2, dx1, 4, -1);
        hurt(build, float(dx0 + 1), 1.0, -2.0, float(dx1 - 1), 4.0, -1.0, 10);
        boulders(build, dice, 6, 5, self.long - 6, wy - 3, 0, dice.between(3, 5), [[0, 1, 6, 7], [10, wy - w - 2, 17, wy], [self.long - 17, wy - w - 2, self.long - 10, wy], [self.long - 6, 1, self.long, 7], [6, wy - 3, 12, wy], [self.long - 12, wy - 3, self.long - 6, wy]]);
        build.doorway(ground, self.enter);
        for port in self.taken {
            build.doorway(ground, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.4);
        into = build.touch(1.0, 1.0, 0.0, 4.0, 8.0, 6.0);
        guards(build, into, [[float(self.long // 2) + 0.5, 6.5], [float(self.long // 2) + 4.5, 7.5]], 0, jail5_foes(dice, self.danger, 2), 180.0);
        # Up on the walk, snipers appear on the far tower; more in the
        # passage.
        up = build.touch(11.0, float(wy), float(w), 15.0, float(self.wide - 1), float(w + 6));
        guards(build, up, [[float(self.long) - 3.5, float(wy) - 1.5]], w + 4, jail5_foes(dice, self.danger, 1), 180.0);
        guards(build, up, [[float(self.long) - 10.5, float(wy) + 3.5]], 0, jail5_foes(dice, self.danger, 1, True), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 6) + 0.5, 6.5, 0, jail5_foe(dice, self.danger), 90.0);
        }
        build.foe(9.5, float(self.wide) - 3.5, w, "monster_soldier", 0.0, patrol=[[9.5, float(self.wide) - 3.5], [float(self.long) - 12.5, float(self.wide) - 3.5]]);
        build.foe(float(self.long // 2) + 0.5, 5.5, w + 5, jail5_foe(dice, self.danger, False, True), 90.0);
        build.supply(3.5, float(wy) - 1.5, w + 4, Q2_ARMOR, "q2");
        build.supply(float(self.long // 2) + 0.5, float(wy) + 3.5, 0, Q2_HEALTH, "q2");
    }
}

"""A hall of bunks under a gallery round it, lockers that break."""
node Barracks(Prefab) {
    has gallery: int = 7,
        by_lift: bool = False,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Barracks";
        self.source = JAIL5;
        self.district = level_district(JAIL5);
        self.long = dice.between(27, 29);
        self.wide = dice.between(22, 24);
        self.gallery = dice.between(9, 10);
        self.by_lift = dice.chance(0.4);
        self.tall = self.gallery + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
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
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The gallery round three walls, a slab over the floor.
        build.solid(1, 1, g - 1, self.long - 1, 5, g);
        build.solid(1, self.wide - 5, g - 1, self.long - 1, self.wide - 1, g);
        build.solid(self.long - 5, 5, g - 1, self.long - 1, self.wide - 5, g);
        if self.by_lift {
            post_button(build, 9, 6, 0, 0) +>:Fires:+> called_lift(build, 5, 5, 8, 8, 0, g);
            keep_row(build, hall, 4, 4, g, 1, 6);
        } else {
            stair(build, 5, 5, 0, 0, g, 3);
            keep_row(build, hall, 3 + g, 4, g, 1, 4);
        }
        # Bunks in rows across the floor; a guard asleep in some, woken as
        # the player comes in.
        woken = build.touch(1.0, float(middle - 3), 0.0, 4.0, float(middle + 3), 6.0);
        sleepers = build.waiting();
        woken +>:Fires:+> sleepers;
        for (index, x) in enumerate(range(14, self.long - 7, 4)) {
            for y in [7, self.wide - 9] {
                build.solid(x, y, 0, x + 2, y + 2, 2);
                if (index + y) % 3 == 0 {
                    build.foe(float(x) + 1.0, float(y) + 1.0, 2, jail5_foe(dice, self.danger), 90.0, waits=sleepers);
                }
            }
        }
        # Lockers along the floor's south wall under the gallery, each behind
        # a door that breaks; a stash in one.
        for (index, x) in enumerate(range(10, self.long - 8, 5)) {
            build.solid(x, 1, 0, x + 3, 2, 4);
            build.room(x, 1, 0, x + 2, 2, 3);
            build.breakable(float(x), 2.0, 0.0, float(x + 2), 3.0, 3.0, 15);
            build.supply(float(x) + 1.0, 1.5, 0, Q2_AMMO[index % len(Q2_AMMO)] if index > 0 else Q2_ARMOR, "q2");
            if index == 0 {
                build.secret(float(x), 1.0, 0.0, float(x + 2), 3.0, 2.0);
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        up = build.touch(float(self.long - 8), 1.0, float(g), float(self.long - 5), 5.0, float(g + 6));
        guards(build, up, [[float(self.long) - 3.0, float(middle) + 0.5]], g, jail5_foes(dice, self.danger, 1, True), 180.0);
        build.foe(6.5, float(self.wide) - 3.0, g, "monster_soldier", 0.0, patrol=[[6.5, float(self.wide) - 3.0], [float(self.long) - 3.0, float(self.wide) - 3.0], [float(self.long) - 3.0, 3.0], [12.5, 3.0]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 7.5, float(middle) - 2.5 + float(index) * 5.0, 0, jail5_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(self.long) - 3.0, 3.0, g, Q2_HEALTH, "q2");
        drip(build, float(self.long // 2) + 0.5, float(middle) + 0.5, float(self.tall) - 0.5, 3.0);
    }
}

"""A trench of water live with current across the room under a bridge,
the booth over the near end that shuts it off."""
node PowerTrench(Prefab) {
    has deep: int = 5,
        booth: int = 9,
        drawn_bridge: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Power trench";
        self.source = JAIL5;
        self.district = level_district(JAIL5);
        self.long = dice.between(28, 30);
        self.wide = dice.between(19, 21);
        self.deep = dice.between(8, 9);
        self.drawn_bridge = dice.chance(0.5);
        self.tall = self.booth + 7;
        self.low = -self.deep - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=3, along=float(self.long - 4), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        d = self.deep;
        room = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(room, self.booth);
        # The trench across the room, water in it live with current, steps
        # up out of it at both ends.
        tx = 15;
        build.pool(tx, 1, -d, tx + 6, self.wide - 1, 0, 2, False, True, True);
        current = hurt(build, float(tx), 1.0, float(-d), float(tx + 6), float(self.wide - 1), -1.0, 8);
        # The bridge over it: fixed, or drawn out from the booth.
        lane = middle - 2;
        if self.drawn_bridge {
            bridge = build.drawn(float(tx), float(lane), float(tx + 6), float(lane + 4), 0, d + 1);
        } else {
            build.solid(tx, lane, -1, tx + 6, lane + 4, 0);
        }
        for y in range(lane, lane + 4) {
            build.keep(room, tx - 1, y, 0);
            build.keep(room, tx + 6, y, 0);
        }
        # The booth over the near end, up a stair along its side; its console
        # shuts the current off (and draws the bridge).
        build.solid(1, 1, self.booth - 1, 10, self.wide - 1, self.booth);
        stair(build, 10, 1, 0, 1, self.booth, 3);
        keep_row(build, room, 9, self.booth - 2, self.booth, 0, 3);
        build.solid(1, middle - 2, self.booth, 2, middle + 2, self.booth + 2);
        press = build.push(2.0, float(middle) + 0.5, float(self.booth) + 0.8, 0);
        press +>:Fires:+> current;
        if self.drawn_bridge {
            press +>:Fires:+> bridge;
            build.touch(float(tx - 3), float(lane), 0.0, float(tx - 1), float(lane + 4), 6.0, True, "The bridge is worked from the booth");
        }
        press +>:Fires:+> build.objective("Current off");
        build.touch(float(tx - 3), 1.0, 0.0, float(tx - 1), float(lane), 6.0, True, "The water is live");
        # Live wires spark along the trench.
        for (index, y) in enumerate([3, self.wide - 4]) {
            sparking(build, float(tx) - 0.2, float(y) + 0.5, -1.0, 2, 2.5 + float(index));
            sparking(build, float(tx + 6) + 0.2, float(y) + 0.5, -1.0, 0, 3.0 + float(index));
        }
        build.doorway(room, self.enter);
        for port in self.taken {
            build.doorway(room, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        # Coming in, a guard appears in the booth; crossing, guards appear
        # on the far side.
        coming = build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 6.0);
        guards(build, coming, [[6.5, 4.5]], self.booth, jail5_foes(dice, self.danger, 1), 0.0);
        over = build.touch(float(tx + 6), float(lane), 0.0, float(tx + 8), float(lane + 4), 6.0);
        guards(build, over, [[float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5]], 0, jail5_foes(dice, self.danger, 2, True), 180.0);
        build.foe(5.5, float(self.wide) - 3.5, self.booth, jail5_foe(dice, self.danger), 0.0);
        build.foe(float(tx + 8) + 0.5, 3.5, 0, "monster_soldier", 90.0, patrol=[[float(tx + 8) + 0.5, 3.5], [float(tx + 8) + 0.5, float(self.wide) - 3.5]]);
        build.supply(float(self.long) - 2.5, float(middle) + 3.5, 0, Q2_HEALTH, "q2");
        build.supply(float(tx) + 3.5, float(self.wide) - 3.5, -d, "ammo_cells", "q2");
    }
}

"""A hall with a gallery round three sides, weapon cases behind glass
that breaks."""
node Armory(Prefab) {
    has gallery: int = 8,
        by_lift: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Armory";
        self.source = JAIL5;
        self.district = level_district(JAIL5);
        self.long = dice.between(26, 28);
        self.wide = dice.between(20, 22);
        self.gallery = dice.between(8, 9);
        self.by_lift = dice.chance(0.4);
        self.tall = self.gallery + 8;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=3, along=float(self.long // 2), floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gallery;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The gallery round the north, south and far walls.
        build.solid(5, 1, g - 1, self.long - 1, 7, g);
        build.solid(5, self.wide - 7, g - 1, self.long - 1, self.wide - 1, g);
        build.solid(self.long - 5, 7, g - 1, self.long - 1, self.wide - 7, g);
        if self.by_lift {
            post_button(build, 1, 6, 0, 0) +>:Fires:+> called_lift(build, 2, 1, 5, 4, 0, g);
            keep_row(build, hall, 5, 1, g, 0, 5);
        } else {
            stair(build, 6 + g - 1, 7, 0, 2, g, 3);
            build.solid(5, 7, g - 1, 6, 10, g);
            keep_row(build, hall, 5, 6, g, 1, 3);
        }
        # Weapon cases along the gallery's back walls, behind glass that
        # breaks; breaking the first raises the alarm.
        alarm: list[Cue] = [];
        for (index, x) in enumerate(range(9, self.long - 7, 5)) {
            if abs(x + 1 - self.long // 2) < 5 {
                continue;
            }
            for south in [True, False] {
                y_case = 1 if south else self.wide - 3;
                build.solid(x, y_case, g, x + 3, y_case + 2, g + 4);
                build.room(x, 1 if south else self.wide - 2, g, x + 2, 2 if south else self.wide - 1, g + 3);
                glass = build.breakable(float(x), 2.0 if south else float(self.wide - 3), float(g), float(x + 2), 3.0 if south else float(self.wide - 2), float(g + 3), 10);
                build.supply(float(x) + 1.0, 1.5 if south else float(self.wide) - 1.5, g, Q2_AMMO[(index + 1) % len(Q2_AMMO)], "q2");
                if not alarm {
                    alarm.append(glass);
                }
            }
        }
        if alarm {
            charges(build, alarm[0], [[float(self.long // 2) + 0.5, float(middle) + 0.5, 1.0], [8.5, float(middle) + 3.5, 1.0]], 0.5);
            guards(build, alarm[0], [[float(self.long) - 3.0, float(middle) + 0.5], [float(self.long // 2) + 0.5, float(self.wide) - 5.0]], g, jail5_foes(dice, self.danger, 2, True), 180.0);
        }
        crate_heaps(build, dice, 8, 8, self.long - 11, self.wide - 8, 0, dice.between(2, 4), [[0, middle - 3, 9, middle + 3]]);
        # A live panel by a broken console on the floor.
        build.solid(self.long - 8, middle - 1, 0, self.long - 7, middle + 1, 3);
        hurt(build, float(self.long - 10), float(middle - 1), 0.0, float(self.long - 8), float(middle + 1), 1.0, 6);
        sparking(build, float(self.long - 8) - 0.2, float(middle) + 0.5, 2.0, 2, 2.0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        auto_shutters(build, dice, self, self.taken, 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(10 + index * 5) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, jail5_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(7.5, 5.0, g, "monster_soldier", 0.0, patrol=[[7.5, 5.0], [float(self.long) - 3.0, 5.0]]);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key room: the pyramid key on top of the captain's tower up a stair
winding round it; taking it blows open the closets."""
node CaptainQuarters(Prefab) {
    has key: str = "key_silver",
        steps: int = 9,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Captain quarters (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = JAIL5;
        self.district = level_district(JAIL5);
        self.long = dice.between(22, 24);
        self.wide = 24;
        self.steps = dice.between(14, 18);
        self.tall = self.steps + 8;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=12.0, floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = 4;
        cx = self.long // 2 + 1;
        cy = 14;
        hall = build.room(1, side + 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(hall, self.steps);
        build.doorway(hall, self.enter);
        # The tower, a stair winding round it from its near corner.
        build.solid(cx - 2, cy - 2, 0, cx + 2, cy + 2, self.steps);
        spiral(build, cx - 5, cy - 5, cx + 5, cy + 5, 0, self.steps, 3, 2, dice.below(8));
        # The key on its top; taking it blows open the closets along the near
        # wall, and charges go off about the tower.
        taken = key_cue(build, self.key, float(cx), float(cy), self.steps);
        for (index, x) in enumerate([3, 8, 13] if dice.chance(0.5) else [4, 11]) {
            build.room(x, 1, 0, x + 3, side, 7);
            front = build.breakable(float(x), float(side), 0.0, float(x + 3), float(side + 1), 6.0, 30);
            taken +>:Fires:+> front;
            build.foe(float(x) + 1.5, 2.5, 0, jail5_foe(dice, self.danger, index == 0), 90.0);
        }
        charges(build, taken, [[float(cx) - 6.5, float(cy) + 0.5, 1.0], [float(cx) + 6.5, float(cy) + 0.5, 1.0]], 0.6);
        taken +>:Fires:+> build.objective("Pyramid key acquired. Return with it");
        guards(build, taken, [[2.5, float(self.wide) - 3.5]], 0, jail5_foes(dice, self.danger, 1, True), 0.0);
        build.foe(float(cx) + 0.5, float(cy) + 6.5, 0, "monster_soldier", 180.0, patrol=[[float(cx) + 6.5, float(cy) + 6.5], [float(cx) - 5.5, float(cy) + 6.5]]);
        build.foe(float(cx) + 1.0, float(cy) + 1.0, self.steps, jail5_foe(dice, self.danger), 180.0);
        build.supply(2.5, float(side) + 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door out to a yard, the way out on a dais up steps."""
node GuardExit(Prefab) {
    has key: str = "",
        dais: int = 3,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Guard exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = JAIL5;
        self.district = level_district(JAIL5);
        self.long = dice.between(25, 27);
        self.wide = dice.between(18, 20);
        self.dais = dice.between(2, 3);
        self.tall = dice.between(16, 20);
        self.low = -3;
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
        gate_pair(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        # The dais at the far end, steps up its front, the way out on it.
        dx = self.long - 8;
        build.solid(dx, middle - 4, 0, self.long - 1, middle + 4, self.dais);
        stair(build, dx - self.dais, middle - 2, 0, 0, self.dais, 4);
        build.way_out(float(dx) + 4.0, float(middle), self.dais);
        # A fire pit by the dais, two lifts deep, that hurts.
        build.room(dx - 6, 2, -2, dx - 2, 6, 0);
        build.solid(dx - 6, 2, -2, dx - 5, 6, -1);
        hurt(build, float(dx - 5), 2.0, -2.0, float(dx - 2), 6.0, -1.0, 10);
        sparking(build, float(dx) - 4.0, 4.0, -1.0, 1, 1.5);
        # Coming out, guards appear by the dais.
        come_out = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards(build, come_out, [[float(self.long) - 3.5, float(middle) + 5.5], [float(self.long) - 3.5, float(middle) - 5.5], [float(dx) + 3.0, float(middle) + 2.5]], 0, jail5_foes(dice, self.danger, 3, True), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, jail5_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(wall) + 3.5, float(self.wide) - 3.5, 0, "monster_soldier", 0.0, patrol=[[float(wall) + 3.5, float(self.wide) - 3.5], [float(dx) - 2.5, float(self.wide) - 3.5]]);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 12, jail5_foe(dice, self.danger, False, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""jail5's stretches: [name, role]."""
glob JAIL5_STRETCHES: list[list[str]] = [
         ["courtyard", "start"],
         ["battlement", "flow"],
         ["barracks", "hub"],
         ["barracks", "flow"],
         ["trench", "flow"],
         ["armory", "flow"],
         ["armory", "hub"],
         ["captain", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of jail5's stretches by its name."""
def make_jail5(name: str, key: str) -> Prefab {
    if name == "courtyard" {
        return GuardCourtyard();
    }
    if name == "battlement" {
        return Battlement();
    }
    if name == "barracks" {
        return Barracks();
    }
    if name == "trench" {
        return PowerTrench();
    }
    if name == "armory" {
        return Armory();
    }
    if name == "captain" {
        return CaptainQuarters(key=key if key else "key_silver");
    }
    return GuardExit(key=key);
}
