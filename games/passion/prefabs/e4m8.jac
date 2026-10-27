"""Prefabs drawn from e4m8, the Nameless City: a dead city under the sky,
streets between blocks of stone and the houses of its dead, terraces
stepping down the slope it stands on, a plaza round a building climbed by
a stair winding up its outside, an abyss under the city with its great
lift and a stair of lifts climbing out, the key on a roof. Raised in
e4m8's own palette.

- `CityStreet`: the start. A street between blocks of buildings, alleys
  between them, a plaza up steps at its far end. The houses' doors open
  one after another as the player comes down the street and the dead come
  out; spikes fly across an alley; a bridge between two roofs spans the
  street, up a stair; a block hides a closet opened by a shot.
- `CityTerraces`: terraces stepping down a slope, each overhanging the one
  below, a stair down between the first two and a stair (or a lift)
  between the last; spikes sweep the first stair, the dead come out of a
  house on the middle terrace behind the player, and the bottom's guards
  wake as the player comes down to them.
- `NamelessPlaza`: a plaza round a building, a stair winding up its
  outside to the roof and a bridge from the roof to a way on high in the
  plaza's wall; ways on below too (a hub). Three fiends in the plaza, all
  dead (a counter), open a chamber inside the building.
- `AbyssShaft`: an abyss under the city. The great lift waits at the top
  beside the way in; a button sends it down (another at the bottom calls
  it), or the player drops into the pool far below. From the bottom a
  stair of lifts climbs the far wall, ledge over ledge, to a way on as
  high as the way in; another way on leaves the bottom through a door
  shot open (e4m8's deep shaft, its thousand-unit lift and its stair of
  plats).
- `DeadQuarter`: a sunken street between raised walkways over its edges,
  the houses of the dead behind the walkways; crossing the bridge over it
  opens the houses one by one; spikes fly down its length; some seeds
  flood it.
- `RooftopKey`: the key room. A building in a court, a hall inside it, a
  lift to its roof; the key in a shrine on the roof opened when the court's
  three fiends are dead, or lying on the roof opening the closets.
- `CityExit`: the end. A door (a key's, as a gate) into a court, the
  slipgate in a temple up a stair, a balcony from the temple along the
  court's wall; the dead come out of the court's walls and the temple's
  guard wakes as the player climbs."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, key_ambush, key_item, spiral, ring_landing }
import from .e4m6 { flood, onward_ports, port_door }
import from .e4m7 { counted_foe }

glob E4M8: str = "q1:e4m8";

"""e4m8's foes: the dead above all, ogres and fiends, hell knights and a
shambler deeper in."""
def e4m8_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_demon1"] if heavy else ["monster_zombie", "monster_zombie", "monster_ogre"], ["monster_hell_knight", "monster_shambler"] if heavy else ["monster_demon1"], danger * 0.5 if heavy else danger));
}

"""The spans [x0, x1] of blocks along a street from `x0` to `x1`, an
alley three cells wide between each and the next, none across `alley`
(x, three cells each way)."""
def block_spans(dice: Stream, x0: int, x1: int, alley: int) -> list[list[int]] {
    found: list[list[int]] = [];
    x = x0;
    while x + 4 <= x1 {
        end = min(x + dice.between(4, 6), x1);
        if end > alley - 3 and x < alley + 3 {
            x = alley + 3;
            continue;
        }
        found.append([x, end]);
        x = end + 3;
    }
    return found;
}

"""A house of the dead in a block of the street's -y side (`low`) or +y
side, its front on the street at the cell line `front`: a closet three
cells wide at x..x+3 on lift `z` behind a door that opens when `cue`
fires, and a zombie in it that wakes with it."""
def dead_house(build: Raising, x: int, front: int, low: bool, cue: Cue, kind: str, z: int = 0) {
    if low {
        build.room(x, front - 3, z, x + 3, front - 1, z + 6);
        cue +>:Fires:+> build.opened(float(x), float(front - 1), float(z), float(x + 3), float(front), float(z + 6));
        wake = build.waiting();
        cue +>:Fires:+> wake;
        build.foe(float(x) + 1.5, float(front) - 2.0, z, kind, 90.0, waits=wake);
    } else {
        build.room(x, front + 1, z, x + 3, front + 3, z + 6);
        cue +>:Fires:+> build.opened(float(x), float(front), float(z), float(x + 3), float(front + 1), float(z + 6));
        wake = build.waiting();
        cue +>:Fires:+> wake;
        build.foe(float(x) + 1.5, float(front) + 2.0, z, kind, 270.0, waits=wake);
    }
}

"""The start: a street between blocks, a plaza up steps at its far end,
the houses of the dead, a bridge between two roofs."""
node CityStreet(Prefab) {
    has plaza: int = 3,
        deep: int = 5,
        roof: int = 7,
        bridge_x: int = 10,
        bridge_here: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "City street";
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.long = dice.between(34, 36);
        self.wide = dice.between(22, 26);
        self.tall = dice.between(18, 22);
        self.plaza = dice.between(3, 4);
        self.roof = dice.between(7, 8);
        self.bridge_here = dice.chance(0.6);
        # The bridge and its stair's block short of the alley.
        alley = self.long // 2;
        spots = list(range(self.roof + 2, alley - 6));
        self.bridge_x = spots[dice.below(len(spots))];
        self.low = -1;
        self.high = self.tall + 8;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.plaza), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        if self.bridge_here {
            self.leaves.append(Port(face=1, along=float(self.bridge_x + 2), floor=self.roof));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        street = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(street, self.plaza);
        px = self.long - 8;
        alley = self.long // 2;
        d = self.deep;
        spans = block_spans(dice, 4, px - 1, alley);
        reach = self.bridge_x + 5 if self.bridge_here else self.bridge_x;
        spans = [span for span in spans if span[1] < self.bridge_x - self.roof - 2 or span[0] > reach];
        # The blocks, a house of the dead in some, a hidden closet in one.
        houses: list[list[int]] = [];
        hidden: list[int] = [];
        for (index, span) in enumerate(spans) {
            for low in [True, False] {
                y0 = 1 if low else self.wide - 1 - d;
                build.solid(span[0], y0, 0, span[1], y0 + d, dice.between(8, 12));
                if span[1] - span[0] >= 5 {
                    if not hidden and not low and dice.chance(0.4) {
                        hidden = span;
                    } elif len(houses) < 4 {
                        houses.append([span[0] + 1, 1 if low else 0]);
                    }
                }
            }
        }
        build.solid(px, 1, 0, self.long - 1, self.wide - 1, self.plaza);
        stair(build, px - self.plaza, middle - 3, 0, 0, self.plaza, 6);
        for y in range(middle - 3, middle + 3) {
            build.keep(street, px, y, self.plaza);
        }
        # The bridge between two roofs across the street, up a stair beside
        # the -y block.
        if self.bridge_here {
            bx = self.bridge_x;
            # The -y block runs on behind the stair, so no alley opens behind
            # it.
            build.solid(bx - self.roof - 1, 1, 0, bx + 4, 1 + d, self.roof);
            build.solid(bx, self.wide - 1 - d, 0, bx + 4, self.wide - 1, self.roof);
            build.solid(bx, 1 + d, self.roof - 1, bx + 4, self.wide - 1 - d, self.roof);
            stair(build, bx - self.roof, 1 + d, 0, 0, self.roof, 3);
            for y in range(1 + d, 4 + d) {
                build.keep(street, bx - 1, y, self.roof);
            }
            build.foe(float(bx) + 2.0, float(self.wide) - 3.5, self.roof, "monster_ogre", 270.0);
            build.supply(float(bx) + 2.0, 3.0, self.roof, "item_rockets");
        } else {
            # Or a gallery along the -y blocks' fronts over the street, up the
            # same stair.
            bx = self.bridge_x;
            build.solid(bx - self.roof - 1, 1, 0, bx, 1 + d, self.roof);
            build.solid(bx, 1 + d, self.roof - 1, px - 1, 4 + d, self.roof);
            stair(build, bx - self.roof, 1 + d, 0, 0, self.roof, 3);
            for y in range(1 + d, 4 + d) {
                build.keep(street, bx - 1, y, self.roof);
            }
            build.foe(float(px) - 3.5, float(d) + 2.5, self.roof, "monster_ogre", 180.0);
            build.supply(float(px) - 2.5, float(d) + 2.5, self.roof, "item_rockets");
        }
        build.doorway(street, self.enter);
        for port in self.taken {
            build.doorway(street, port);
        }
        # Coming down the street, the houses' doors open one after another.
        down = build.touch(float(self.long // 3), float(d + 1), 0.0, float(self.long // 3 + 2), float(self.wide - 1 - d), 6.0);
        for (index, house) in enumerate(houses) {
            late = build.delay(1.0 + 1.5 * float(index));
            down +>:Fires:+> late;
            dead_house(build, house[0], 1 + d if house[1] == 1 else self.wide - 1 - d, house[1] == 1, late, "monster_zombie" if index % 2 == 0 else e4m8_foe(dice, self.danger));
        }
        # Spikes fly across the alley while anyone is in it.
        in_alley = build.touch(float(alley - 2), 1.0, 0.0, float(alley + 2), float(1 + d), 6.0, False);
        later = build.delay(0.5);
        in_alley +>:Fires:+> later;
        later +>:Fires:+> build.spikes(float(alley - 3) + 0.1, 3.5, 2.0, 0);
        # A closet in a block, opened by a shot.
        if hidden {
            y0 = self.wide - 1 - d;
            build.room(hidden[0] + 1, y0 + 2, 0, hidden[0] + 3, y0 + 4, 4);
            build.secret_door(float(hidden[0] + 1), float(y0), 0.0, float(hidden[0] + 3), float(y0 + 2), 4.0, 1);
            build.secret(float(hidden[0] + 1), float(y0 + 2), 0.0, float(hidden[0] + 3), float(y0 + 4), 3.0);
            build.supply(float(hidden[0]) + 2.0, float(y0) + 3.0, 0, "item_artifact_super_damage");
        }
        # Climbing to the plaza brings a fiend in behind the player.
        steps_up = build.touch(float(px - self.plaza), float(middle - 3), 0.0, float(px), float(middle + 3), 6.0);
        steps_up +>:Fires:+> build.summon(px + 1, 1, self.tall + 1, "monster_demon1" if self.danger > 0.2 else "monster_zombie", float(px) - 6.5, float(middle) + 0.5, 0, 0.0);
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        for index in range(dice.between(2, 3)) {
            build.foe(float(8 + index * 5) + 0.5, float(middle) + (2.5 if index % 2 == 0 else -2.5), 0, e4m8_foe(dice, self.danger), 180.0);
        }
        build.foe(float(px) - 4.5, float(middle) + 0.5, 0, "monster_ogre", 180.0, patrol=[[float(px) - 4.5, float(middle) + 0.5], [6.5, float(middle) + 0.5]]);
        build.foe(float(self.long) - 3.5, float(middle) + 3.5, self.plaza, e4m8_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 2.5, 2.5, self.plaza, "item_health");
    }
}

"""Terraces stepping down a slope, each overhanging the one below, stairs
(or a lift) down between."""
node CityTerraces(Prefab) {
    has drop: int = 6,
        over: int = 3,
        third: int = 13,
        lift_down: bool = False,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "City terraces";
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.drop = dice.between(6, 7);
        self.over = dice.between(3, 5);
        self.third = self.over + self.drop + dice.between(4, 5);
        self.long = 3 * self.third + 1;
        self.wide = dice.between(18, 20);
        self.lift_down = dice.chance(0.5);
        self.tall = dice.between(14, 16);
        self.low = -2 * self.drop - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        bottom = -2 * self.drop;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=bottom),
            Port(face=3, along=float(self.long - 4), floor=bottom),
            Port(face=1, along=5.0, floor=0),
            Port(face=3, along=float(self.third + self.over + self.drop + 2), floor=-self.drop)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        bottom = -2 * self.drop;
        t = self.third;
        o = self.over;
        slope = build.room(1, 1, bottom, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(slope, 0);
        build.level(slope, -self.drop);
        # The terraces, each a slab out over the next below.
        build.solid(1, 1, bottom, t, self.wide - 1, 0);
        build.solid(t, 1, -1, t + o, self.wide - 1, 0);
        build.solid(t, 1, bottom, 2 * t, self.wide - 1, -self.drop);
        build.solid(2 * t, 1, -self.drop - 1, 2 * t + o, self.wide - 1, -self.drop);
        # Down from the first to the second: a stair off the slab's lip.
        first_x = t + o + self.drop - 1;
        stair(build, first_x, middle - 2, -self.drop, 2, self.drop, 4);
        for y in range(middle - 2, middle + 2) {
            build.keep(slope, t + o - 1, y, 0);
        }
        # Down from the second to the bottom: a stair, or a lift.
        second_x = 2 * t + o;
        if self.lift_down {
            build.put_box({"classname": "func_plat", "height": str(self.drop * 16), "speed": "150"}, float(second_x), 2.0, float(-self.drop) - 0.5, float(second_x + 3), 5.0, float(-self.drop), kit_of(build.district).step);
        } else {
            stair(build, second_x + self.drop - 1, 2, bottom, 2, self.drop, 3);
        }
        for y in range(2, 5) {
            build.keep(slope, second_x - 1, y, -self.drop);
        }
        # Buildings on the terraces, clear of the stairs' heads and feet; the
        # middle one a house of the dead.
        build.solid(2, 2, 0, 6, 6, dice.between(5, 8));
        build.solid(t + o + 1, self.wide - 6, -self.drop, t + o + 6, self.wide - 1, -self.drop + 7);
        build.solid(2 * t + o + self.drop + 1, self.wide - 6, bottom, 2 * t + o + self.drop + 5, self.wide - 2, bottom + dice.between(5, 8));
        build.doorway(slope, self.enter);
        for port in self.taken {
            build.doorway(slope, port);
        }
        # Spikes sweep the first stair while anyone is on it.
        on_stair = build.touch(float(t + o), float(middle - 2), float(-self.drop), float(first_x + 1), float(middle + 2), 4.0, False);
        on_stair +>:Fires:+> build.spikes(float(first_x) - 1.0, 1.1, float(-self.drop) + 3.0, 1);
        # Coming down to the bottom wakes its guards and opens the house
        # behind the player.
        down = build.touch(float(second_x), 1.0, float(bottom), float(second_x + self.drop + 2), 7.0, float(bottom + 6));
        guards = build.waiting();
        down +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(2 * t + o + 4 + index * 3) + 0.5, float(middle) + 1.5, bottom, e4m8_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        late = build.delay(1.0);
        down +>:Fires:+> late;
        dead_house(build, t + o + 2, self.wide - 6, False, late, "monster_zombie", -self.drop);
        px = float(t + o + self.drop) + 1.5;
        build.foe(px, 2.5, -self.drop, "monster_ogre", 90.0, patrol=[[px, 2.5], [px, float(self.wide) - 2.5]]);
        build.foe(float(t) - 3.5, float(middle) + 3.5, 0, e4m8_foe(dice, self.danger), 0.0);
        build.supply(float(self.long) - 2.5, 2.5, bottom, "item_health");
        build.supply(float(t) - 2.5, 2.5, 0, "item_shells");
        build.supply(float(t) + 1.5, float(middle) + 4.5, -self.drop, "item_rockets");
    }
}

"""A plaza round a building, a stair winding up its outside to the roof, a
bridge from the roof to a way on high in the plaza's wall; a chamber in
the building opened by the plaza's fiends' deaths."""
node NamelessPlaza(Prefab) {
    has steps: int = 6,
        chamber: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Nameless plaza";
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.long = dice.between(26, 28);
        self.wide = dice.between(24, 26);
        cx = self.long // 2;
        cy = self.wide // 2;
        fits: list[int] = [];
        for steps in range(8, 20) {
            landing = ring_landing(cx - 6, cy - 6, cx + 6, cy + 6, 2, steps, 3);
            if landing and landing[0] == 0.0 {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))];
        self.chamber = dice.chance(0.65) and self.steps >= 10;
        self.tall = self.steps + 12;
        self.low = -1;
        self.high = self.tall + 1;
        top = ring_landing(cx - 6, cy - 6, cx + 6, cy + 6, 2, self.steps, 3);
        middle = float(cy);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=top[1], floor=self.steps), Port(face=3, along=float(cx), floor=0), Port(face=1, along=float(cx), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        plaza = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(plaza, self.steps);
        build.solid(cx - 4, cy - 4, 0, cx + 4, cy + 4, self.steps);
        landing = spiral(build, cx - 6, cy - 6, cx + 6, cy + 6, 0, self.steps, 2, 3);
        mid = landing[1];
        build.solid(mid[2], mid[1] - 3, self.steps - 1, self.long - 1, mid[1] + 4, self.steps);
        for y in range(mid[1] - 3, mid[1] + 4) {
            build.keep(plaza, mid[2] - 1, y, self.steps);
        }
        build.doorway(plaza, self.enter);
        for port in self.taken {
            build.doorway(plaza, port);
        }
        # The chamber in the building, its door on the -x face (clear of the
        # stair), opened when the plaza's three fiends are dead.
        slain = build.cue([], "slain");
        if self.chamber {
            inside = build.room(cx - 3, cy - 3, 0, cx + 3, cy + 3, self.steps - 2, variant=dice.below(3));
            build.widen(inside, cx - 4, cy - 1, 0, cx - 3, cy + 2, 6);
            count = build.tally(3, "A chamber has opened");
            slain +>:Fires:+> count;
            count +>:Fires:+> build.opened(float(cx - 4), float(cy - 1), 0.0, float(cx - 3), float(cy + 2), 6.0);
            build.supply(float(cx) + 1.5, float(cy) + 0.5, 0, "item_artifact_super_damage" if dice.chance(0.5) else "item_armor2");
            build.supply(float(cx) - 1.5, float(cy) + 0.5, 0, "item_health");
        }
        for index in range(3) {
            if self.chamber {
                counted_foe(build, float(cx + 8) + 0.5, 3.5 + float(index) * 6.0, 0, "monster_demon1", 180.0, slain);
            } else {
                build.foe(float(cx + 8) + 0.5, 3.5 + float(index) * 6.0, 0, e4m8_foe(dice, self.danger), 180.0);
            }
        }
        # The roof's guards wake as the player passes the stair's middle.
        half = landing[0];
        roused = build.touch(float(cx - 6), float(cy - 6), 1.0, float(cx + 6), float(cy - 4), float(self.steps // 2 + 4));
        guards = build.waiting();
        roused +>:Fires:+> guards;
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.steps, e4m8_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(half[0]) + 1.0, float(half[1]) + 1.0, self.steps, "monster_ogre", 180.0, waits=guards);
        corners = [[float(cx - 8) + 0.5, float(cy - 8) + 0.5], [float(cx + 8) + 0.5, float(cy - 8) + 0.5], [float(cx + 8) + 0.5, float(cy + 8) + 0.5], [float(cx - 8) + 0.5, float(cy + 8) + 0.5]];
        build.foe(corners[0][0], corners[0][1], 0, "monster_ogre" if self.danger > 0.3 else "monster_zombie", 0.0, patrol=corners);
        build.supply(float(cx) - 2.5, float(cy) + 2.5, self.steps, "item_health");
        build.supply(3.0, 3.0, 0, "item_rockets");
    }
}

"""An abyss under the city: the great lift beside the way in, a pool far
below, a stair of lifts up the far wall to a way on as high as the way
in; another way on through a door at the bottom."""
node AbyssShaft(Prefab) {
    has rungs: int = 3,
        pool_here: bool = True,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Abyss shaft";
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.rungs = dice.between(3, 4);
        self.pool_here = dice.chance(0.6);
        deep = 7 * self.rungs;
        self.long = 12 + 6 * self.rungs + 3;
        self.wide = dice.between(18, 20);
        self.tall = dice.between(11, 13);
        self.low = -deep - 6;
        self.high = self.tall + 8;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide - 3), floor=0),
            Port(face=0, along=4.0, floor=-deep),
            Port(face=1, along=float(self.long - 4), floor=0),
            Port(face=3, along=float(self.long - 5), floor=-deep)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        deep = 7 * self.rungs;
        step = kit_of(build.district).step;
        shaft = build.room(1, 1, -deep, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, 0);
        # The ledge the way in opens on.
        build.solid(1, 1, -deep, 4, self.wide - 1, 0);
        build.solid(4, 1, -1, 6, self.wide - 1, 0);
        # The great lift, waiting at the top beside the ledge: a button on
        # the ledge sends it down, one at the bottom calls it.
        plat = {"classname": "func_plat", "height": str(deep * 16), "speed": "300"};
        build.put_box(plat, 6.0, float(middle - 2), -0.5, 10.0, float(middle + 2), 0.0, step);
        great = build.cue([plat], "lift");
        for y in range(middle - 2, middle + 2) {
            build.keep(shaft, 5, y, 0);
        }
        build.push(4.0, 1.0, 1.5, 1) +>:Fires:+> great;
        called = build.push(4.0, float(middle + 4) + 0.5, float(-deep) + 1.5, 0);
        called +>:Fires:+> great;
        # A pool far below under the ledge's lip, to drop into.
        if self.pool_here {
            build.pool(11, 2, -deep - 4, self.long - 11, self.wide - 8, -deep, 2, False, True, True);
            build.foe(14.5, 4.5, -deep - 3, "monster_fish", 0.0);
        }
        for y in range(1, self.wide - 1) {
            if y < middle - 3 or y > middle + 2 {
                build.keep(shaft, 5, y, 0);
            }
        }
        # The stair of lifts up the +y wall: ledges a rung apart, each a
        # slab out over the bottom, a lift up to each from the one below.
        xs = 12;
        for k in range(self.rungs) {
            h = -deep + 7 * (k + 1);
            x0 = xs + 6 * k;
            x1 = self.long - 1 if k == self.rungs - 1 else x0 + 6;
            build.solid(x0, self.wide - 6, h - 1, x1, self.wide - 1, h);
            build.put_box({"classname": "func_plat", "height": str(7 * 16), "speed": "150"}, float(x0 - 3), float(self.wide - 5), float(h) - 0.5, float(x0), float(self.wide - 2), float(h), step);
            for y in range(self.wide - 5, self.wide - 1) {
                build.keep(shaft, x0, y, h);
            }
            if k < self.rungs - 1 {
                build.foe(float(x0) + 2.5, float(self.wide) - 2.5, h, "monster_ogre", 270.0);
            }
        }
        # A closet in the ledge's foot behind a stretch of wall opened by a
        # shot.
        build.room(1, 2, -deep, 3, 5, -deep + 4);
        build.secret_door(3.0, 2.0, float(-deep), 4.0, 5.0, float(-deep + 4), 2);
        build.secret(1.0, 2.0, float(-deep), 3.0, 5.0, float(-deep + 3));
        build.supply(2.0, 3.5, -deep, "item_artifact_super_damage");
        # A teleporter at the bottom back up to the ledge.
        build.teleporter(float(self.long) - 9.5, float(self.wide) - 9.5, -deep, 2.5, float(middle) + 0.5, 0, 0.0);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # The ways on at the bottom are through doors opened by shooting the
        # button over each.
        for port in onward_ports(self) {
            if port.floor < 0 {
                if port.face == 0 {
                    shot = build.push(float(self.long - 1), port.along, float(port.floor + 9), 2, True);
                } else {
                    shot = build.push(port.along, 1.0, float(port.floor + 9), 1, True);
                }
                shot +>:Fires:+> port_door(build, self, port);
            }
        }
        # The dead at the bottom wake as the great lift goes down.
        below = build.waiting();
        great +>:Fires:+> below;
        landed = build.touch(6.0, float(middle - 2), float(-deep), 12.0, float(middle + 2), float(-deep + 6));
        landed +>:Fires:+> below;
        for index in range(dice.between(3, 5)) {
            build.foe(float(self.long) - 4.5 - float(index % 2) * 3.0, 3.5 + float(index) * 2.0, -deep, "monster_zombie" if index % 2 == 0 else e4m8_foe(dice, self.danger), 180.0, waits=below);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, -deep, "monster_hell_knight" if self.danger > 0.3 else "monster_ogre", 180.0, patrol=[[float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(self.wide) - 8.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(13.5, float(self.wide) - 9.5, -deep, "item_rockets");
    }
}

"""A sunken street between raised walkways over its edges, the houses of
the dead behind them; crossing the bridge over it opens the houses."""
node DeadQuarter(Prefab) {
    has trench: int = 7,
        canal: bool = False,
        bridge_here: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dead quarter";
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.trench = 7;
        self.canal = dice.chance(0.35);
        self.bridge_here = dice.chance(0.7);
        self.long = dice.between(28, 32);
        self.wide = dice.between(24, 26);
        self.tall = dice.between(15, 17);
        self.low = -self.trench - 1;
        self.high = self.tall + 8;
        self.enter = Port(face=2, along=7.0, floor=0);
        self.leaves = [
            Port(face=0, along=7.0, floor=0),
            Port(face=0, along=float(self.wide - 8), floor=0),
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=3, along=float(self.long // 2), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        quarter = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        alley = self.long // 2;
        # The sunken street, stairs down into it at both ends, the walkways'
        # lips over its edges.
        y0 = 8;
        y1 = self.wide - 8;
        z = -self.trench;
        build.room(4, y0, z, self.long - 4, y1, 0, variant=dice.below(3));
        build.level(quarter, z);
        stair(build, 4 + self.trench - 1, y0, z, 2, self.trench, y1 - y0);
        stair(build, self.long - 4 - self.trench, y0, z, 0, self.trench, y1 - y0);
        x_in = 4 + self.trench;
        x_out = self.long - 4 - self.trench;
        build.solid(x_in, y0, -1, x_out, y0 + 2, 0);
        build.solid(x_in, y1 - 2, -1, x_out, y1, 0);
        if self.canal {
            flood(build, 4, y0, z, self.long - 4, y1, z + 4);
        }
        # The bridge across it at the alleys.
        if self.bridge_here {
            build.solid(alley - 2, y0 + 2, -1, alley + 2, y1 - 2, 0);
            for x in range(alley - 2, alley + 2) {
                build.keep(quarter, x, y0 + 1, 0);
                build.keep(quarter, x, y1 - 2, 0);
            }
        }
        # The houses behind the walkways, an alley through each row.
        build.solid(4, 1, 0, self.long - 4, 5, 9);
        build.solid(4, self.wide - 5, 0, self.long - 4, self.wide - 1, 9);
        build.widen(quarter, alley - 2, 1, 0, alley + 2, 5, 9);
        build.widen(quarter, alley - 2, self.wide - 5, 0, alley + 2, self.wide - 1, 9);
        build.doorway(quarter, self.enter);
        for port in self.taken {
            build.doorway(quarter, port);
        }
        crossing = build.touch(float(alley - 2), float(y0), -1.0, float(alley + 2), float(y1), 6.0) if self.bridge_here else build.touch(float(alley - 2), float(y0), float(z), float(alley + 2), float(y1), float(z + 6));
        index = 0;
        for x in list(range(6, alley - 5, 6)) + list(range(alley + 4, self.long - 7, 6)) {
            for low in [True, False] {
                if index < 6 and dice.chance(0.7) {
                    late = build.delay(0.8 + 1.2 * float(index));
                    crossing +>:Fires:+> late;
                    dead_house(build, x, 5 if low else self.wide - 5, low, late, "monster_zombie" if index % 3 != 2 else e4m8_foe(dice, self.danger));
                    index += 1;
                }
            }
        }
        crossing +>:Fires:+> build.summon(1, 1, self.tall + 1, e4m8_foe(dice, self.danger, True), float(alley) - 4.5, 6.5, 0, 0.0);
        # Spikes fly down the sunken street while anyone is in it.
        sunk = build.touch(float(x_in), float(y0 + 2), float(z), float(x_out), float(y1 - 2), float(z + 5), False);
        later = build.delay(1.5);
        sunk +>:Fires:+> later;
        later +>:Fires:+> build.spikes(float(x_out) + 0.5, float(middle), float(z) + 3.0, 2);
        build.foe(6.5, 7.5, 0, "monster_ogre", 0.0, patrol=[[6.5, 7.5], [float(self.long) - 6.5, 7.5]]);
        build.foe(float(self.long) - 6.5, float(self.wide) - 7.5, 0, e4m8_foe(dice, self.danger, True), 180.0);
        build.foe(float(alley) + 0.5, float(middle) + 0.5, z, e4m8_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "item_shells");
        build.supply(float(alley) - 4.5, float(middle) + 0.5, z, "item_rockets");
    }
}

"""The key room: a building in a court, a hall inside it, a lift to its
roof; the key in a shrine on the roof opened by the court's fiends'
deaths, or lying on the roof opening the closets."""
node RooftopKey(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 16,
        roof: int = 7,
        shrine: bool = True,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rooftop key (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.long = dice.between(24, 26);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.roof = dice.between(7, 8);
        self.shrine = dice.chance(0.6);
        self.tall = self.roof + 10;
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
        court = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.roof);
        build.doorway(court, self.enter);
        bx = self.long - 12;
        build.solid(bx, cy - 3, 0, self.long - 2, cy + 3, self.roof);
        # A hall inside the building, its door on the +y face.
        inside = build.room(bx + 1, cy - 2, 0, self.long - 3, cy + 2, self.roof - 2, variant=dice.below(3));
        build.widen(inside, bx + 2, cy + 2, 0, bx + 5, cy + 3, 6);
        build.put_box({"classname": "func_plat", "height": str(self.roof * 16), "speed": "200"}, float(bx - 3), float(cy - 1), float(self.roof) - 0.5, float(bx), float(cy + 2), float(self.roof), kit_of(build.district).step);
        for y in range(cy - 2, cy + 3) {
            build.keep(court, bx, y, self.roof);
        }
        if self.shrine {
            # The shrine on the roof, its door opened when the court's three
            # fiends are dead; the key in it, and what lies in the hall below
            # wakes when it is taken.
            build.solid(self.long - 7, cy - 3, self.roof, self.long - 2, cy + 3, self.roof + 6);
            build.room(self.long - 6, cy - 2, self.roof, self.long - 3, cy + 2, self.roof + 5);
            count = build.tally(3, "The shrine is open");
            slain = build.cue([], "slain");
            slain +>:Fires:+> count;
            count +>:Fires:+> build.opened(float(self.long - 7), float(cy - 1), float(self.roof), float(self.long - 6), float(cy + 2), float(self.roof + 5));
            for index in range(3) {
                counted_foe(build, 4.5 + float(index) * 4.0, float(side) - 2.5 - float(index % 2) * 3.0, 0, "monster_demon1", 0.0, slain);
            }
            key = build.cue([], "key");
            fields = {"classname": key_item(self.key), "asset_game": "q1"};
            key.items.append(fields);
            build.put_at(fields, float(self.long) - 4.0, float(cy) + 0.5, self.roof);
            hidden = build.waiting();
            key +>:Fires:+> hidden;
            for index in range(2) {
                build.foe(float(bx) + 3.5 + float(index) * 3.0, float(cy) + 0.5, 0, e4m8_foe(dice, self.danger, index == 0), 90.0, waits=hidden);
            }
            build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0, True, "Slay the fiends to open the shrine");
        } else {
            key_ambush(build, self.key, float(self.long) - 4.5, float(cy) + 0.5, self.roof, side, 0, [2, bx - 4], [e4m8_foe(dice, self.danger, True), "monster_zombie"]);
            build.foe(float(bx) + 3.5, float(cy) + 0.5, 0, e4m8_foe(dice, self.danger), 90.0);
        }
        build.foe(float(self.long) - 8.5, float(cy) - 2.0, self.roof, e4m8_foe(dice, self.danger), 180.0);
        build.foe(3.0, 2.5, 0, "monster_zombie", 0.0, patrol=[[3.0, 2.5], [float(bx) - 4.5, 2.5]]);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 5.5, float(cy) + 0.5, 0, "item_rockets");
    }
}

"""The end: a door into a court, the slipgate in a temple up a stair, a
balcony from the temple along the court's wall."""
node CityExit(Prefab) {
    has key: str = "",
        temple: int = 6,
        balcony: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "City exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M8;
        self.district = level_district(E4M8);
        self.long = dice.between(26, 28);
        self.wide = dice.between(18, 20);
        self.temple = dice.between(6, 7);
        self.balcony = dice.chance(0.65);
        self.tall = dice.between(18, 20);
        self.low = -1;
        self.high = self.tall + 8;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 8;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        court = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, self.temple);
        build.doorway(hall, self.enter);
        build.widen(court, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        tx = self.long - 7;
        build.solid(tx, 2, 0, self.long - 1, self.wide - 2, self.temple);
        stair(build, tx - self.temple, middle - 2, 0, 0, self.temple, 4);
        for y in range(middle - 2, middle + 2) {
            build.keep(court, tx, y, self.temple);
        }
        pillars(build, tx + 1, 3, self.long - 1, self.wide - 3, self.temple, self.temple + 8, 3, [[tx - 1, middle - 3, self.long, middle + 3]]);
        build.way_out(float(self.long) - 3.5, float(middle), self.temple);
        # The balcony along the +y wall back from the temple, a slab over the
        # court.
        if self.balcony {
            build.solid(wall + 2, self.wide - 5, self.temple - 1, tx, self.wide - 1, self.temple);
            build.foe(float(wall) + 3.5, float(self.wide) - 3.0, self.temple, "monster_ogre", 0.0);
            build.supply(float(wall) + 2.5, float(self.wide) - 2.0, self.temple, "item_rockets");
        }
        # The dead come out of the court's -y wall as the player comes in;
        # the temple's guard wakes as the player climbs.
        into = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        for index in range(dice.between(2, 3)) {
            x = wall + 3 + index * 5;
            if x + 3 < tx - self.temple - 1 {
                late = build.delay(0.5 + float(index));
                into +>:Fires:+> late;
                build.solid(x - 1, 1, 0, x + 4, 4, 8);
                dead_house(build, x, 4, True, late, "monster_zombie");
            }
        }
        climb = build.touch(float(tx - self.temple), float(middle - 2), 1.0, float(tx), float(middle + 2), float(self.temple + 6));
        guard = build.waiting();
        climb +>:Fires:+> guard;
        build.foe(float(self.long) - 3.5, float(middle) + 3.5, self.temple, "monster_shambler" if self.danger > 0.6 else e4m8_foe(dice, self.danger, True), 180.0, waits=guard);
        on_stair = build.touch(float(tx - self.temple), float(middle - 2), 0.0, float(tx), float(middle + 2), float(self.temple + 4), False);
        on_stair +>:Fires:+> build.spikes(float(tx) - 2.0, 2.1, float(self.temple) + 1.0, 1);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e4m8_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(tx) - 9.5, float(middle) + 4.5, 0, e4m8_foe(dice, self.danger), 0.0, patrol=[[float(tx) - 9.5, float(middle) + 4.5], [float(tx) - 9.5, float(middle) - 3.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m8's stretches: [name, role]."""
glob E4M8_STRETCHES: list[list[str]] = [
         ["street", "start"],
         ["terraces", "flow"],
         ["plaza", "hub"],
         ["plaza", "flow"],
         ["abyss", "flow"],
         ["abyss", "hub"],
         ["quarter", "flow"],
         ["rooftop", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m8's stretches by its name."""
def make_e4m8(name: str, key: str) -> Prefab {
    if name == "street" {
        return CityStreet();
    }
    if name == "terraces" {
        return CityTerraces();
    }
    if name == "plaza" {
        return NamelessPlaza();
    }
    if name == "abyss" {
        return AbyssShaft();
    }
    if name == "quarter" {
        return DeadQuarter();
    }
    if name == "rooftop" {
        return RooftopKey(key=key if key else "key_gold");
    }
    return CityExit(key=key);
}
