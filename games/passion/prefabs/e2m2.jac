"""Prefabs drawn from e2m2, the Ogre Citadel: a citadel of wood and brick
under the sky, its moat, its walls with ogres along their tops, a tower
climbed by a stair winding up its walls, a keep in a courtyard bridged to
from high up, a gallery of spike traps, a pit of lifts, the gold key on a
gallery or down in a pit. Raised in e2m2's own palette.

- `CitadelApproach`: the start. Open ground, a moat across it, the
  citadel's wall beyond with its gate, ogres along the wall's top. The
  two buttons on the wall must both be shot (e2m2's "Shoot the buttons"
  counter): they draw the bridge over the moat out of the water, or sink
  the gate's portcullis; spikes fly across the passage through the wall
  while anyone is in it (its spike shooters); a closet in the wall's foot
  opens to a shot.
- `SpiralTower`: a tower, a stair winding round its walls between its foot
  and a landing high up, climbed or come down by the dice; a floor across
  its middle at half height may roof the foot; what waits up the stair
  wakes as the player passes its middle.
- `CitadelCourt`: a courtyard round a keep, a stair (or a lift) up the keep
  and a bridge from its top to a way on high in the courtyard's wall, a
  second bridge now and then; ways on below too (a hub). A platform rides
  up and down beside the keep (e2m2's train), a teleporter may send a body
  from the ground onto the keep (e2m2's), knights walk round it and its
  top, its guard wakes at the stair's top, a closet in its foot opens to a
  shot.
- `SpikeGallery`: a long hall, a walkway along one side over its floor;
  spikes fly across the floor as the player walks it (e2m2's spike traps),
  the gate at its end sinks as the player comes to it or when the button
  at the walkway's end is pressed; ogres on the walkway.
- `OgrePit`: a pit under a ledge, a stair down its wall and a lift up, a
  catwalk across it now and then (e2m2's pits of lifts); come down into
  it or climbed out of it, by the dice.
- `OgreGoldHall`: the key room. A hall, the key on a gallery across its
  far end ridden up to by a lift, or down in a pit with a lift back up and
  a closet at its foot; taking the key opens the closets in the wall.
- `CitadelSally`: the end. A hall, a gate out (a key's, as a gate) to a
  yard, the slipgate on a dais up a stair or up on the wall-walk, ogres on
  the wall over it, roused as the player comes through the gate."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from ..space { Space }
import from .roster { FoeMix }
import from .common { stair, pillars, key_ambush, ring_path, spiral, lift }
import from .e1m1_parts { deck, stash, bars }

glob E2M2: str = "q1:e2m2";

"""e2m2's foes: knights and ogres, fiends and a shambler deeper in."""
glob E2M2_FOES: FoeMix = FoeMix(light=["monster_knight", "monster_knight", "monster_zombie"], strong=["monster_ogre"], heavy_light=["monster_ogre", "monster_knight"], heavy_strong=["monster_demon1"]);

"""What a secret of e2m2's holds."""
def e2m2_reward(dice: Stream) -> str {
    return ["item_armor2", "item_artifact_super_damage", "weapon_grenadelauncher", "item_artifact_envirosuit"][dice.below(4)];
}

"""Crenels along a wall-walk's open edge: a merlon a cell square and two
lifts high every other cell along the line `line` (y, or x when not
`along_x`) from `start` to `finish`, on lift `z`, none in `gap`
([low, high) along the line)."""
def merlons(build: Raising, line: int, start: int, finish: int, z: int, along_x: bool, gap: list[int] | None = None) {
    for at in range(start, finish, 2) {
        if gap is not None and gap[0] <= at and at < gap[1] {
            continue;
        }
        if along_x {
            build.solid(at, line, z, at + 1, line + 1, z + 2);
        } else {
            build.solid(line, at, z, line + 1, at + 1, z + 2);
        }
    }
}

"""Every cell of the box kept clear of railings on lift `z`, so a body can
step off the edge into the water."""
def keep_box_e2m2(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int) {
    for x in range(x0, x1) {
        for y in range(y0, y1) {
            build.keep(space, x, y, z);
        }
    }
}

"""The start: open ground, a moat, the citadel's wall and gate."""
node CitadelApproach(Prefab) {
    has wall: int = 10,
        tall: int = 20,
        drawbridge: bool = False,
        spread: int = 5,
        hidden: bool = False,
        hide_low: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Citadel approach";
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 24);
        self.tall = dice.between(18, 22);
        self.wall = dice.between(10, 12);
        self.drawbridge = dice.chance(0.5);
        self.spread = dice.between(4, 6);
        self.hidden = dice.chance(0.6);
        self.hide_low = dice.chance(0.5);
        self.low = -10;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long - 9), floor=0), Port(face=1, along=float(self.long - 9), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        ground = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(ground, self.wall);
        # The moat across the ground, steps out of it on the near bank.
        wall_x = self.long - 6;
        moat0 = 8;
        moat1 = min(18, wall_x - 6);
        build.pool(moat0, 1, -8, moat1, self.wide - 1, 0, 2);
        for y in range(middle - 2, middle + 2) {
            build.keep(ground, moat0 - 1, y, 0);
            build.keep(ground, moat1, y, 0);
        }
        # The citadel's wall, its gate through it, merlons along its top.
        build.solid(wall_x, 1, 0, self.long - 1, self.wide - 1, self.wall);
        build.widen(ground, wall_x, middle - 2, 0, self.long - 1, middle + 2, 8);
        merlons(build, wall_x, 1, self.wide - 1, self.wall, False);
        build.doorway(ground, self.enter);
        for port in self.taken {
            build.doorway(ground, port);
        }
        # Both buttons on the wall's face shot, the bridge is drawn up out
        # of the moat (or stands, and the portcullis sinks into the ground).
        both = build.tally(2, "The way is open");
        for side in [-self.spread, self.spread] {
            build.cue([build.button(float(wall_x), float(middle + side) + 0.5, 5.0, 2, "", True)], "button") +>:Fires:+> both;
        }
        if self.drawbridge {
            both +>:Fires:+> build.drawn(float(moat0), float(middle - 2), float(moat1), float(middle + 2), 0, 9);
            build.touch(float(moat0 - 3), 1.0, 0.0, float(moat0), float(self.wide - 1), 8.0, True, "Shoot the buttons to lower the bridge");
        } else {
            build.solid(moat0, middle - 2, -1, moat1, middle + 2, 0);
            both +>:Fires:+> build.sinking(float(wall_x), float(middle - 2), float(wall_x + 1), float(middle + 2), 8, 8);
            build.touch(float(moat0 - 1), 1.0, 0.0, float(moat0), float(self.wide - 1), 8.0, True, "Shoot the buttons to open the gate");
        }
        # Spikes across the passage through the wall while anyone is in it.
        inside = build.touch(float(wall_x + 1), float(middle - 2), 0.0, float(self.long - 2), float(middle + 2), 6.0, False);
        inside +>:Fires:+> build.spikes(float(wall_x) + 3.0, float(middle - 2) + 0.2, 2.5, 1);
        inside +>:Fires:+> build.spikes(float(wall_x) + 4.0, float(middle + 2) - 0.2, 2.5, 3);
        # A closet in the wall's foot, its face opening to a shot.
        if self.hidden {
            stash(build, wall_x, 2 if self.hide_low else self.wide - 6, 0, 2, e2m2_reward(dice));
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall_x) + 2.5, 2.5 + float(index) * 5.0, self.wall, "monster_ogre", 180.0);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall_x) - 3.5, float(middle) + 3.5 - float(index) * 7.0, 0, E2M2_FOES.pick(dice, self.danger), 180.0);
        }
        # A knight walking the far bank.
        build.foe(float(moat1) + 2.5, 2.5, 0, "monster_knight", 90.0, patrol=[[float(moat1) + 2.5, 2.5], [float(moat1) + 2.5, float(self.wide) - 2.5]]);
        build.supply(float(wall_x) - 2.5, 2.5, 0, "item_health");
    }
}

"""The landing's floor, face and middle along that face for a spiral of
`steps` up a ring three cells wide round the box 1..long-1, 1..wide-1:
[face, along], or [] when the landing turns a corner."""
def spiral_landing(long: int, wide: int, steps: int, landing: int) -> list[float] {
    path = ring_path(1, 1, long - 1, wide - 1, 3);
    lap = len(path);
    face = path[steps % lap][4];
    for index in range(landing) {
        if path[(steps + index) % lap][4] != face {
            return [];
        }
    }
    cell = path[(steps + landing // 2) % lap];
    along = float(cell[0]) + 0.5 if face % 2 == 1 else float(cell[1]) + 0.5;
    return [float(face), along];
}

"""Whether a doorway on face `face` at `along` (four cells wide, eight
lifts high from the floor) leaves the winding stair of `steps` round the
ring of the box 1..long-1, 1..wide-1 whole: each ring cell it cuts is a
step high enough to pass under, or no step at all."""
def foot_clear(long: int, wide: int, steps: int, landing: int, face: int, along: float) -> bool {
    path = ring_path(1, 1, long - 1, wide - 1, 3);
    for (index, cell) in enumerate(path) {
        if index >= steps + landing or cell[4] != face {
            continue;
        }
        at = float(cell[0]) + 0.5 if face % 2 == 1 else float(cell[1]) + 0.5;
        if abs(at - along) < 3.0 and index + 1 - 3 < 9 {
            return False;
        }
    }
    return True;
}

"""A tower, a stair winding round its walls between its foot and a landing
high up; a floor across its middle may roof the foot."""
node SpiralTower(Prefab) {
    has steps: int = 18,
        tall: int = 28,
        down: bool = False,
        mezz: int = -1;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spiral tower";
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(14, 16);
        self.wide = dice.between(14, 16);
        self.down = dice.chance(0.45);
        middle = float(self.wide // 2);
        fits: list[int] = [];
        for steps in range(14, 23) {
            landing = spiral_landing(self.long, self.wide, steps, 6);
            if not landing {
                continue;
            }
            if self.down {
                if landing[0] == 2.0 and foot_clear(self.long, self.wide, steps, 6, 0, middle) {
                    fits.append(steps);
                }
            } elif landing[0] != 2.0 {
                fits.append(steps);
            }
        }
        if not fits {
            self.down = False;
            for steps in range(14, 23) {
                landing = spiral_landing(self.long, self.wide, steps, 6);
                if landing and landing[0] != 2.0 {
                    fits.append(steps);
                }
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.tall = self.steps + 10;
        # The floor across the middle, at the height of a step beside it
        # that is not at a corner, half way up.
        self.mezz = -1;
        if dice.chance(0.5) {
            path = ring_path(1, 1, self.long - 1, self.wide - 1, 3);
            for index in range(self.steps // 2 - 2, self.steps // 2 + 3) {
                cell = path[index];
                if self.mezz < 0 and cell[0] >= 4 and cell[2] <= self.long - 4 and cell[1] >= 4 and cell[3] <= self.wide - 4 {
                    self.mezz = index;
                }
                if self.mezz < 0 and ((cell[4] % 2 == 1 and cell[0] >= 4 and cell[2] <= self.long - 4) or (cell[4] % 2 == 0 and cell[1] >= 4 and cell[3] <= self.wide - 4)) {
                    self.mezz = index;
                }
            }
        }
        self.low = -1;
        self.high = self.tall + 1;
        top = spiral_landing(self.long, self.wide, self.steps, 6);
        if self.down {
            self.enter = Port(face=2, along=top[1], floor=self.steps);
            self.leaves = [Port(face=0, along=middle, floor=0)];
        } else {
            self.enter = Port(face=2, along=middle, floor=0);
            self.leaves = [Port(face=int(top[0]), along=top[1], floor=self.steps), Port(face=0, along=middle, floor=0)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(tower, self.steps // 2);
        build.level(tower, self.steps);
        landing = spiral(build, 1, 1, self.long - 1, self.wide - 1, 0, self.steps, 3, 6);
        path = ring_path(1, 1, self.long - 1, self.wide - 1, 3);
        # The floor across the middle, stepped onto from the stair beside it,
        # a stretch of its edge left open to drop from.
        if self.mezz >= 0 {
            floor = self.mezz + 1;
            build.level(tower, floor);
            deck(build, 4, 4, self.long - 4, self.wide - 4, floor);
            cell = path[self.mezz];
            for x in range(cell[0] - 1, cell[2] + 1) {
                for y in range(cell[1] - 1, cell[3] + 1) {
                    build.keep(tower, x, y, floor);
                }
            }
            for x in range(5, 8) {
                build.keep(tower, x, self.wide - 5, floor);
            }
            build.foe(float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, floor, E2M2_FOES.pick(dice, self.danger, True), 90.0);
            build.supply(float(self.long // 2) - 1.5, float(self.wide // 2) + 0.5, floor, "item_shells");
        }
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
        }
        mid = landing[3];
        # What waits up the stair wakes as the player passes its middle.
        half = path[self.steps // 2];
        roused = build.touch(float(half[0]), float(half[1]), float(self.steps // 2 + 1), float(half[2]), float(half[3]), float(self.steps // 2 + 7));
        above = build.waiting();
        roused +>:Fires:+> above;
        build.foe(float(mid[0] + mid[2]) * 0.5, float(mid[1] + mid[3]) * 0.5, self.steps, E2M2_FOES.pick(dice, self.danger, True), 180.0, waits=above);
        for index in range(dice.between(1, 2)) {
            cell = path[self.steps // 2 + index * 3];
            build.foe(float(cell[0] + cell[2]) * 0.5, float(cell[1] + cell[3]) * 0.5, self.steps // 2 + index * 3 + 1, E2M2_FOES.pick(dice, self.danger), 90.0, waits=above);
        }
        # A knight walking round the foot.
        build.foe(4.5, 4.5, 0, "monster_knight", 0.0, patrol=[[4.5, 4.5], [float(self.long) - 4.5, 4.5], [float(self.long) - 4.5, float(self.wide) - 4.5], [4.5, float(self.wide) - 4.5]]);
        build.supply(float(self.long // 2) - 1.5, float(self.wide // 2) + 0.5, 0, "item_health");
        top = landing[5];
        build.supply(float(top[0] + top[2]) * 0.5, float(top[1] + top[3]) * 0.5, self.steps, "item_rockets");
    }
}

"""A courtyard round a keep, a stair (or a lift) up the keep and a bridge
from its top to a way on high in the courtyard's wall (or two)."""
node CitadelCourt(Prefab) {
    has keep_top: int = 8,
        tall: int = 22,
        lifted: bool = False,
        two: bool = False,
        tele: bool = False,
        pools: bool = False,
        called: bool = False,
        hidden: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Citadel court";
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(30, 32);
        self.two = dice.chance(0.5);
        self.wide = dice.between(26, 28) if self.two else dice.between(24, 28);
        self.tall = dice.between(20, 24);
        self.keep_top = dice.between(8, 9);
        self.lifted = dice.chance(0.4);
        self.tele = dice.chance(0.5);
        self.pools = True;
        self.called = dice.chance(0.5);
        self.hidden = dice.chance(0.6);
        self.low = -8;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=1, along=float(self.long // 2), floor=self.keep_top), Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        if self.two {
            self.leaves.append(Port(face=0, along=float(self.wide - 8) - 2.0, floor=self.keep_top));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.keep_top);
        # The keep, solid to its top, a stair (or a lift) up its south face.
        kx0 = 10;
        kx1 = self.long - 9;
        ky0 = 8;
        ky1 = self.wide - 8;
        build.solid(kx0, ky0, 0, kx1, ky1, self.keep_top);
        if self.lifted {
            lift(build, kx0 + 3, ky0 - 3, kx0 + 6, ky0, 0, self.keep_top);
            for x in range(kx0 + 3, kx0 + 6) {
                build.keep(court, x, ky0, self.keep_top);
            }
            climb_x = kx0 + 3;
        } else {
            stair(build, kx0, ky0 - 3, 0, 0, self.keep_top, 3);
            for x in range(kx0 + self.keep_top - 3, kx0 + self.keep_top) {
                build.keep(court, x, ky0, self.keep_top);
            }
            climb_x = kx0 + self.keep_top - 3;
        }
        # The bridge from the keep's north side to the wall's way on.
        bx = self.long // 2;
        build.solid(bx - 2, ky1, self.keep_top - 1, bx + 2, self.wide - 1, self.keep_top);
        for x in range(bx - 2, bx + 2) {
            build.keep(court, x, ky1, self.keep_top);
            build.keep(court, x, ky1 - 1, self.keep_top);
        }
        # The second, from its east side to the east wall's high way on.
        if self.two {
            deck(build, kx1, ky1 - 4, self.long - 1, ky1, self.keep_top);
            for y in range(ky1 - 4, ky1) {
                build.keep(court, kx1, y, self.keep_top);
                build.keep(court, kx1 - 1, y, self.keep_top);
            }
        }
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        # A platform riding up and down beside the keep's far face, from the
        # start or once the button on the keep's face calls it.
        ride = build.train([3.0, 3.0, 1.0], [[float(kx1), float(ky0 + 1), 0.0], [float(kx1), float(ky0 + 1), float(self.keep_top - 1)]], 80.0, 3.0, self.called);
        if self.called {
            build.push(float(kx1), float(ky0) + 5.5, 2.5, 0) +>:Fires:+> ride;
        }
        # Pools either side of the causeway from the way in to the keep.
        if self.pools {
            middle = self.wide // 2;
            build.pool(2, 2, -7, kx0 - 2, middle - 3, 0, 2, False, True, True);
            build.pool(2, middle + 3, -7, kx0 - 2, self.wide - 2, 0, 2, False, True, True);
        }
        # The ground behind the keep stands two steps up, under the bridge.
        build.solid(kx0, ky1, 0, kx1, self.wide - 1, 2);
        build.solid(kx0 - 1, ky1, 0, kx0, self.wide - 1, 1);
        build.solid(kx1, ky1, 0, kx1 + 1, self.wide - 1, 1);
        for y in range(ky0 + 1, ky0 + 4) {
            build.keep(court, kx1 - 1, y, self.keep_top);
        }
        # A teleporter in a corner of the ground sends a body up onto the
        # keep.
        if self.tele {
            build.teleporter(float(self.long) - 3.5, float(self.wide) - 3.5, 0, float(kx0) + 2.5, float(ky1) - 2.5, self.keep_top, 0.0);
        }
        # A closet in the keep's north foot, opening to a shot.
        if self.hidden {
            stash(build, kx0 + 1, ky1 - 4, 0, 1, e2m2_reward(dice));
        }
        # The keep's guard wakes as the player comes up.
        top_touch = build.touch(float(climb_x), float(ky0), float(self.keep_top), float(climb_x + 4), float(ky0 + 3), float(self.keep_top + 6));
        guard = build.waiting();
        top_touch +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(kx0 + 3 + index * 4) + 0.5, float(ky0) + 3.5, self.keep_top, E2M2_FOES.pick(dice, self.danger, True), 270.0, waits=guard);
        }
        # Knights walking their rounds about the keep, and on its top.
        ring = [[float(kx0) - 1.5, float(ky1) + 2.5], [float(kx1) + 4.5, float(ky1) + 2.5], [float(kx1) + 4.5, float(ky0) - 4.5], [float(kx0) - 1.5, float(ky0) - 4.5]];
        build.foe(float(kx0) - 1.5, float(ky1) + 2.5, 0, "monster_knight", 0.0, patrol=ring);
        build.foe(float(kx0) + 1.5, float(ky1) - 1.5, self.keep_top, "monster_knight", 0.0, patrol=[[float(kx0) + 1.5, float(ky1) - 1.5], [float(kx1) - 1.5, float(ky1) - 1.5]]);
        for index in range(dice.between(2, 4)) {
            build.foe(float(kx1) + 4.5, 4.5 + float(index) * 5.0, 0, E2M2_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(float(kx1) - 2.5, float(ky0) + 2.5, self.keep_top, "item_health");
        build.supply(float(kx0) - 1.0, 2.5, 0, "item_spikes");
        build.supply(float(self.long) - 3.5, 3.5, 0, "item_health");
    }
}

"""A long hall, a walkway along one side over its floor, spikes across the
floor, a gate at its end."""
node SpikeGallery(Prefab) {
    has tall: int = 15,
        walk: int = 6,
        walk_low: bool = True,
        by_button: bool = False,
        hidden: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spike gallery";
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(26, 30);
        self.wide = dice.between(13, 15);
        self.tall = dice.between(14, 16);
        self.walk = dice.between(6, 7);
        self.walk_low = dice.chance(0.5);
        self.by_button = dice.chance(0.5);
        self.hidden = dice.chance(0.6);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        walk_y = 3.0 if self.walk_low else float(self.wide) - 3.0;
        self.enter = Port(face=2, along=middle + (1.0 if self.walk_low else -1.0), floor=0);
        self.leaves = [
            Port(face=0, along=middle + (1.0 if self.walk_low else -1.0), floor=0),
            Port(face=0, along=walk_y, floor=self.walk),
            Port(face=3 if self.walk_low else 1, along=float(self.long - 4), floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.walk);
        # The walkway along one side, a deck over the floor, and its stair up
        # at the near end.
        y0 = 1 if self.walk_low else self.wide - 4;
        far_y = self.wide - 1 if self.walk_low else 1;
        stair(build, 2, y0, 0, 0, self.walk, 3);
        deck(build, 2 + self.walk, y0, self.long - 1, y0 + 3, self.walk);
        deck(build, self.long - 4, y0 if self.walk_low else y0 - 1, self.long - 1, y0 + 4 if self.walk_low else y0 + 3, self.walk);
        edge_y = y0 + 2 if self.walk_low else y0;
        # A stretch of its edge short of the end unrailed, to drop down to
        # the gate.
        for x in range(self.long - 8, self.long - 5) {
            build.keep(hall, x, edge_y, self.walk);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Spikes across the floor from the far wall as the player walks it, a
        # stretch at a time.
        lane0 = float(y0 + 3) if self.walk_low else 1.0;
        lane1 = float(self.wide - 1) if self.walk_low else float(y0);
        # The floor's middle sunk three steps, the spikes flying over it.
        sunk0 = 11;
        sunk1 = self.long - 11;
        build.widen(hall, sunk0, int(lane0), -3, sunk1, int(lane1), 0);
        for step in range(2) {
            build.solid(sunk0 + step, int(lane0), -3, sunk0 + step + 1, int(lane1), -1 - step);
            build.solid(sunk1 - step - 1, int(lane0), -3, sunk1 - step, int(lane1), -1 - step);
        }
        shoot_out = 3 if self.walk_low else 1;
        wall_line = float(far_y) - (0.2 if self.walk_low else -0.2);
        for start in range(8, self.long - 6, 6) {
            stretch = build.touch(float(start), lane0, -3.0, float(start + 4), lane1, 5.0, False);
            stretch +>:Fires:+> build.spikes(float(start) + 2.0, wall_line, 2.0, shoot_out);
            if dice.chance(0.5) {
                stretch +>:Fires:+> build.spikes(float(start) + 4.0, wall_line, 3.5, shoot_out);
            }
        }
        # The gate at the floor's end: it sinks as the player comes to it,
        # or only when the button at the walkway's end is pressed.
        for port in self.taken {
            if port.floor == 0 and port.face == 0 {
                low = port.along - float(port.wide) * 0.5;
                gate = build.sinking(float(self.long - 1), low, float(self.long), low + float(port.wide), 8, 8);
                if self.by_button {
                    build.push(float(self.long // 2) + 0.5, 1.0 if self.walk_low else float(self.wide - 1), float(self.walk) + 2.0, 1 if self.walk_low else 3) +>:Fires:+> gate;
                    build.touch(float(self.long - 5), lane0, 0.0, float(self.long - 1), lane1, 5.0, True, "The gate opens from the walkway");
                } else {
                    build.touch(float(self.long - 5), lane0, 0.0, float(self.long - 2), lane1, 5.0) +>:Fires:+> gate;
                }
            }
        }
        # A closet under the walkway's far end, opening to a shot.
        if self.hidden {
            stash(build, self.long - 9, y0 if self.walk_low else self.wide - 5, 0, 1 if self.walk_low else 3, e2m2_reward(dice));
        }
        # Ogres on the walkway, woken as the player comes in; knights on the
        # floor, one walking it.
        come_in = build.touch(1.0, 1.0, 0.0, 4.0, float(self.wide - 1), 6.0);
        ogres = build.waiting();
        come_in +>:Fires:+> ogres;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 4.5 - float(index) * 7.0, float(y0) + 1.5, self.walk, "monster_ogre", 180.0, waits=ogres);
        }
        floor_y = float(middle) + (2.5 if self.walk_low else -2.5);
        build.foe(6.5, floor_y, 0, "monster_knight", 0.0, patrol=[[6.5, floor_y], [float(self.long) - 6.5, floor_y]]);
        build.foe(float(self.long) - 3.5, floor_y, 0, E2M2_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(2 + self.walk) + 1.5, float(y0) + 1.5, self.walk, "item_health");
        build.supply(float(self.long) - 3.5, floor_y - 2.0, 0, "item_spikes");
    }
}

"""A pit under a ledge, a stair down its wall and a lift up, a catwalk
across it now and then."""
node OgrePit(Prefab) {
    has ledge: int = 6,
        top: int = 11,
        tall: int = 22,
        descend: bool = True,
        catwalk: bool = False,
        stair_low: bool = True,
        flooded: bool = False,
        hidden: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ogre pit";
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(24, 28);
        self.wide = dice.between(16, 18);
        self.top = dice.between(10, 12);
        self.tall = self.top + dice.between(9, 11);
        self.ledge = dice.between(5, 6);
        self.descend = dice.chance(0.55);
        self.catwalk = dice.chance(0.5);
        self.stair_low = dice.chance(0.5);
        self.flooded = True;
        self.hidden = dice.chance(0.6);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        far = float(self.long - 1 - self.ledge) + float(self.ledge) * 0.5;
        if self.descend {
            self.enter = Port(face=2, along=middle, floor=self.top);
            self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=far, floor=0), Port(face=3, along=far, floor=0)];
            if self.catwalk {
                self.leaves.append(Port(face=0, along=middle + 1.0, floor=self.top));
            }
        } else {
            self.enter = Port(face=2, along=middle, floor=0);
            self.leaves = [Port(face=0, along=middle, floor=self.top), Port(face=1, along=far, floor=self.top), Port(face=3, along=far, floor=self.top)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        pit = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, self.top);
        # The high ledge: at the near end going down, at the far end going
        # up; the stair along a side wall and the lift beside it.
        stair_y = 1 if self.stair_low else self.wide - 4;
        lift_y = self.wide - 5 if self.stair_low else 2;
        if self.descend {
            edge_x = 1 + self.ledge;
            build.solid(1, 1, 0, edge_x, self.wide - 1, self.top);
            stair(build, edge_x + self.top - 1, stair_y, 0, 2, self.top, 3);
            lift(build, edge_x, lift_y, edge_x + 3, lift_y + 3, 0, self.top);
            for y in range(lift_y, lift_y + 3) {
                build.keep(pit, edge_x - 1, y, self.top);
            }
            for y in range(stair_y, stair_y + 3) {
                build.keep(pit, edge_x - 1, y, self.top);
            }
            landing_x = edge_x;
        } else {
            edge_x = self.long - 1 - self.ledge;
            build.solid(edge_x, 1, 0, self.long - 1, self.wide - 1, self.top);
            stair(build, edge_x - self.top, stair_y, 0, 0, self.top, 3);
            lift(build, edge_x - 3, lift_y, edge_x, lift_y + 3, 0, self.top);
            for y in range(lift_y, lift_y + 3) {
                build.keep(pit, edge_x, y, self.top);
            }
            for y in range(stair_y, stair_y + 3) {
                build.keep(pit, edge_x, y, self.top);
            }
            landing_x = edge_x - 4;
        }
        # The catwalk across the pit at the ledge's height, to the far wall's
        # high way on (or, going up, back over the pit to a balcony).
        if self.catwalk {
            walk_y = middle - 1;
            if self.descend {
                deck(build, 1 + self.ledge, walk_y, self.long - 1, walk_y + 4, self.top);
                for y in range(walk_y, walk_y + 4) {
                    build.keep(pit, self.ledge, y, self.top);
                }
            } else {
                deck(build, 3, walk_y, self.long - 1 - self.ledge, walk_y + 4, self.top);
                for y in range(walk_y, walk_y + 4) {
                    build.keep(pit, self.long - 1 - self.ledge, y, self.top);
                }
                build.foe(4.5, float(walk_y) + 1.5, self.top, "monster_ogre", 0.0);
            }
        }
        build.doorway(pit, self.enter);
        for port in self.taken {
            build.doorway(pit, port);
        }
        # A pool across the middle of the pit's floor, clear of the stair and
        # the lift, steps out of it at both its ends.
        if self.flooded {
            px0 = 1 + self.ledge + 4 if self.descend else 6;
            px1 = self.long - 5 if self.descend else self.long - 5 - self.ledge;
            build.pool(px0, 6, -7, px1, self.wide - 6, 0, 2, False, True, True);
        }
        # A closet in a side wall of the pit's floor.
        if self.hidden {
            hide_x = self.long - 9 if self.descend else 4;
            stash(build, hide_x, self.wide - 5 if self.stair_low else 1, 0, 3 if self.stair_low else 1, e2m2_reward(dice));
        }
        # What waits in the pit wakes as the player comes down into it (or
        # sets out up it).
        below = build.waiting();
        landed = build.touch(float(landing_x), 1.0, 0.0, float(landing_x + 4), float(self.wide - 1), 6.0);
        landed +>:Fires:+> below;
        # The ways on stay shut until the player is down in the pit (or, going
        # up, has set out across it).
        bars(build, landed, self.taken, self.long, self.wide);
        floor_x = float(self.long) - 4.5 if self.descend else 4.5;
        for index in range(dice.between(2, 3)) {
            build.foe(floor_x, 3.5 + float(index) * 4.0, 0, E2M2_FOES.pick(dice, self.danger, index == 0), 180.0, waits=below);
        }
        build.foe(float(self.long // 2) + 0.5, 5.5, 0, "monster_knight", 0.0, patrol=[[float(self.ledge) + 5.5, 5.5], [float(self.long - self.ledge) - 5.5, 5.5]]);
        ledge_x = 3.5 if self.descend else float(self.long) - 3.5;
        build.foe(ledge_x, float(middle) + 3.5, self.top, "monster_ogre", 180.0 if not self.descend else 0.0);
        build.supply(ledge_x, float(middle) - 2.5, self.top, "item_rockets");
        build.supply(float(self.long // 2) - 2.5, float(self.wide) - 5.5, 0, "item_health");
    }
}

"""A hall, the key on a gallery across its far end ridden up to by a lift,
or down in a pit at its far end with a lift back up; taking it opens the
closets in the wall."""
node OgreGoldHall(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        gallery: int = 8,
        tall: int = 16,
        pit: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ogre hall (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(26, 28);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.gallery = dice.between(7, 9);
        self.pit = dice.between(10, 13) if dice.chance(0.5) else 0;
        self.tall = self.gallery + 9;
        self.low = min(-9, -self.pit - 1);
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
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.doorway(hall, self.enter);
        gx = self.long - 7;
        if self.pit > 0 {
            # The pit at the far end, the lift at its near edge back up, the
            # key on its floor, a closet in its corner.
            bottom = -self.pit;
            pit = build.room(gx, 1, bottom, self.long - 1, side, 0);
            build.level(pit, bottom);
            lift(build, gx, cy - 1, gx + 3, cy + 2, bottom, 0);
            for y in range(cy - 2, cy + 3) {
                build.keep(hall, gx - 1, y, 0);
            }
            stash(build, self.long - 5, 1, bottom, 1, e2m2_reward(dice));
            key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, bottom, side, 0, [4, 9], [E2M2_FOES.pick(dice, self.danger, True), E2M2_FOES.pick(dice, self.danger)]);
            build.foe(float(self.long) - 3.5, float(side) - 2.5, bottom, E2M2_FOES.pick(dice, self.danger, True), 180.0);
            build.touch(float(gx) - 3.0, float(cy - 2), 0.0, float(gx), float(cy + 3), 6.0, True, "The key lies below");
        } else {
            build.level(hall, self.gallery);
            build.solid(gx, 1, 0, self.long - 1, side, self.gallery);
            build.put_box({"classname": "func_plat", "height": str(self.gallery * 16), "speed": "180"}, float(gx - 3), float(cy - 1), float(self.gallery) - 0.5, float(gx), float(cy + 2), float(self.gallery), kit_of(build.district).step);
            for y in range(cy - 2, cy + 3) {
                build.keep(hall, gx, y, self.gallery);
            }
            # A stretch of the gallery's edge unrailed, to drop from.
            for y in range(2, 5) {
                build.keep(hall, gx, y, self.gallery);
            }
            stash(build, self.long - 5, side - 4, self.gallery, 3, e2m2_reward(dice));
            key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, self.gallery, side, 0, [4, 9], [E2M2_FOES.pick(dice, self.danger, True), E2M2_FOES.pick(dice, self.danger)]);
            build.foe(float(self.long) - 3.5, 3.5, self.gallery, E2M2_FOES.pick(dice, self.danger, True), 180.0);
        }
        # A drowned aisle along the south side, its columns standing over it.
        build.pool(8, 2, -8, gx - 3, cy - 1, 0, 2);
        keep_box_e2m2(build, hall, 8, cy - 1, gx - 3, cy, 0);
        pillars(build, 4, 3, gx - 4, 4, 0, self.tall, 4, [[0, cy - 3, 5, cy + 3]]);
        pillars(build, 4, side - 3, gx - 4, side - 2, 0, self.tall, 4, [[0, cy - 3, 5, cy + 3]]);
        build.foe(float(gx) - 6.5, float(cy) + 0.5, 0, E2M2_FOES.pick(dice, self.danger), 180.0);
        build.foe(3.5, float(cy) + 3.5, 0, "monster_knight", 0.0, patrol=[[3.5, float(cy) + 3.5], [float(gx) - 3.5, float(cy) + 3.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a hall, a gate out to a yard, the slipgate on a dais up a
stair (or up on the wall-walk), ogres on the wall over it."""
node CitadelSally(Prefab) {
    has key: str = "",
        tall: int = 18,
        on_wall: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Citadel sally" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M2;
        self.district = level_district(E2M2);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(16, 20);
        self.on_wall = dice.chance(0.5);
        self.low = -8;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        gate_x = 11;
        hall = build.room(1, 1, 0, gate_x, self.wide - 1, 12, variant=dice.below(3));
        yard = build.room(gate_x + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, sky=True);
        build.level(yard, 8);
        build.doorway(hall, self.enter);
        build.widen(yard, gate_x, middle - 2, 0, gate_x + 1, middle + 2, 9);
        if self.key {
            build.rising_door(float(gate_x), float(middle - 2), 0.0, float(gate_x + 1), float(middle + 2), 9.0, {"key": self.key, "wait": "-1"});
        }
        # The moat along the yard's south side, up to the dais's foot.
        build.pool(gate_x + 3, 1, -7, self.long - 1, middle - 3, 0, 2, False, False);
        stair(build, gate_x + 9, 1, -7, 2, 7, 2);
        # The dais at the yard's far end, a stair up its face.
        dais_x = self.long - 6;
        build.solid(dais_x, middle - 3, 0, self.long - 1, middle + 3, 4);
        stair(build, dais_x - 4, middle - 2, 0, 0, 4, 4);
        # The wall-walk along the yard's north side, ogres on it; on the wall
        # a stair climbs to it from the yard and the way out is on it.
        build.solid(gate_x + 1, self.wide - 4, 0, self.long - 1, self.wide - 1, 8);
        climb = [gate_x + 3, gate_x + 7];
        if self.on_wall {
            # The stair climbs back toward the gate, its foot by the dais.
            stair(build, gate_x + 10, self.wide - 7, 0, 2, 8, 3);
            climb = [gate_x + 2, gate_x + 6];
            for x in range(gate_x + 2, gate_x + 6) {
                build.keep(yard, x, self.wide - 4, 8);
            }
            build.way_out(float(self.long) - 3.0, float(self.wide) - 2.5, 8);
            build.foe(float(dais_x) + 2.5, float(middle) + 0.5, 4, E2M2_FOES.pick(dice, self.danger, True), 180.0);
        } else {
            build.way_out(float(self.long) - 3.0, float(middle), 4);
        }
        merlons(build, self.wide - 4, gate_x + 2, self.long - 4, 8, True, climb);
        through = build.touch(float(gate_x + 1), float(middle - 2), 0.0, float(gate_x + 3), float(middle + 2), 6.0);
        wall_guard = build.waiting();
        through +>:Fires:+> wall_guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(gate_x + 13 + index * 4) + 0.5, float(self.wide) - 2.5, 8, "monster_ogre", 270.0, waits=wall_guard);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(gate_x) - 3.5, 2.5 + float(index) * 4.0, 0, E2M2_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(gate_x) + 5.5, float(middle) + 0.5, 0, E2M2_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(gate_x) + 2.5, float(middle) - 1.5, 0, "monster_knight", 0.0, patrol=[[float(gate_x) + 2.5, float(middle) - 1.5], [float(gate_x) + 2.5, float(self.wide) - 8.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e2m2's stretches: [name, role]."""
glob E2M2_STRETCHES: list[list[str]] = [
         ["approach", "start"],
         ["tower", "flow"],
         ["court", "hub"],
         ["court", "flow"],
         ["spikes", "flow"],
         ["pit", "flow"],
         ["hall", "keyroom"],
         ["sally", "end"],
         ["sally", "gate"]
     ];

"""One of e2m2's stretches by its name."""
def make_e2m2(name: str, key: str) -> Prefab {
    if name == "approach" {
        return CitadelApproach();
    }
    if name == "tower" {
        return SpiralTower();
    }
    if name == "court" {
        return CitadelCourt();
    }
    if name == "spikes" {
        return SpikeGallery();
    }
    if name == "pit" {
        return OgrePit();
    }
    if name == "hall" {
        return OgreGoldHall(key=key if key else "key_gold");
    }
    return CitadelSally(key=key);
}
