"""Prefabs drawn from Quake III's q3dm19, Apocalypse Void: gothic rock
islands floating at many heights in a burning void, the platforms between
them bobbing up and down, a keep in the middle of the biggest, jump pads
across the gaps. Quake III's arenas hold no foes of their own; q3dm19's
are knight, ogre, shalrath. Raised in q3dm19's own palette. The void's
floor burns whoever falls, and teleporters on it send them back up.

- `VoidLanding`: the start. An island floating over the void, a balcony
  high over its back thrown up to by a pad (and by the seed reached by a
  bobbing platform too), a stair down its side to a terrace and a pad from the terrace's
  lip over the void to the far ledge.
- `BobbingCrossing`: across the void two ways: a bobbing platform up from
  the near ledge to a high island and a pad from it down to the far
  ledge, or a pad down to a low island and a bobbing platform from it up
  to the far ledge (on one side or the other by the seed), and a pad from
  the low island back up to the high one. Landing on the low island wakes
  what waits on the far ledge.
- `SpireStair`: a stair of floating stones winding up round a rock spire
  out of the void, from the near ledge (at one corner of the spire or
  another) to a high ledge across the far end; from the ledge a pad to the
  spire's top (the railgun's perch), and from the perch one back down to
  the near ledge. Halfway up, the high ledge's guards come out.
- `ApocalypseKeep`: the hub. The great island, a keep in its middle with
  the quad on top, thrown up to by pads (one or two; else a pad from the
  island's far end up onto the far bridge) and a bobbing
  platform up one face, a knight walking his round before another;
  bridges from the keep's top out to high ways on over the island and the
  void; ways on from the island too. Landing on the keep lets loose what
  holds the bridges.
- `SkyAltar`: the key room. The key on an altar island high over the
  void: up by a bobbing platform (or a pad) to a middle island, a pad on
  to the altar; taking the key opens closets on the entry ledge, and a
  teleporter takes the taker back down to them.
- `VoidGate`: the end (or a gate, the door a key's). A hall, a deck out
  over the void, the way out on an island across it: a pad over, and by
  the seed a platform shuttling across too."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from ..space { Space }
import from .common { stair, key_ambush, spiral, ring_path }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .q3late_parts { deck, keep_box, void_floor, throw, wake_later, hurt }

glob Q3DM19: str = "q3:q3dm19",
     Q3DM19_LIGHT: list[str] = ["monster_knight", "monster_ogre"],
     Q3DM19_HEAVY: list[str] = ["monster_shalrath"];

"""A foe for q3dm19's stretches."""
def apocalypse_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    return arena_foe(dice, danger, Q3DM19_LIGHT, Q3DM19_HEAVY, strong);
}

"""A platform bobbing up and down a shaft of the cells x..x+4, y..y+4,
its top flush with lift `bottom` at its foot and `top` at its head, and
the cells round the shaft at each kept clear of railings (`foot` and
`head` say which sides of the shaft have floor there: 0 +x ... 3 -y)."""
def bobbing(build: Raising, space: Space, x: int, y: int, bottom: int, top: int, foot: list[int], head: list[int]) {
    build.train([4.0, 4.0, 1.0], [[float(x), float(y), float(bottom - 1)], [float(x), float(y), float(top - 1)]], 70.0, 2.0);
    for end in range(2) {
        level = bottom if end == 0 else top;
        sides = foot if end == 0 else head;
        for face in sides {
            if face == 0 {
                keep_box(build, space, x + 4, y, x + 5, y + 4, level);
            } elif face == 2 {
                keep_box(build, space, x - 1, y, x, y + 4, level);
            } elif face == 1 {
                keep_box(build, space, x, y + 4, x + 4, y + 5, level);
            } else {
                keep_box(build, space, x, y - 1, x + 4, y, level);
            }
        }
    }
}


"""The void's floor, the cells x0..x1, y0..y1 on lift `z`: it burns
whoever falls to it, and jump pads on it throw them back up (as q3dm19's
pad at the foot of its void does): each of `pads` [x, y, lx, ly, lz]
from (x, y) on the floor to (lx, ly) on lift lz, the landing's edge
`keeps` ([x0, y0, x1, y1, z] each) clear of railings."""
def void_pit(build: Raising, space: Space, x0: int, y0: int, x1: int, y1: int, z: int, pads: list[list[float]], keeps: list[list[int]]) {
    hurt(build, float(x0), float(y0), float(z), float(x1), float(y1), float(z) + 2.0, 8);
    for spot in pads {
        throw(build, space, spot[0], spot[1], z, spot[2], spot[3], int(spot[4]), None, None);
    }
    for box in keeps {
        keep_box(build, space, box[0], box[1], box[2], box[3], box[4]);
    }
}

"""The start: an island over the void, a balcony over its back, a terrace
down its side and a pad from it over to the far ledge."""
node VoidLanding(Prefab) {
    has deep: int = 14,
        terrace_side: int = 0,
        far_z: int = 0,
        balcony: int = 10,
        bob: bool = True,
        tall: int = 21;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Void landing";
        self.source = Q3DM19;
        self.district = level_district(Q3DM19);
        self.long = dice.between(34, 36);
        self.wide = dice.between(20, 22);
        self.deep = 14;
        self.terrace_side = dice.below(2);
        self.far_z = [-2, 0, 2][dice.below(3)];
        self.balcony = dice.between(10, 11);
        self.bob = dice.chance(0.6);
        self.tall = self.balcony + 10;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        ty = 2 if self.terrace_side == 0 else self.wide - 10;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=float(ty) + 4.0, floor=self.far_z), Port(face=1 if self.terrace_side == 0 else 3, along=3.5, floor=self.balcony), Port(face=0, along=float(self.wide - 5) if self.terrace_side == 0 else 5.0, floor=self.far_z)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -self.deep;
        b = self.balcony;
        ty = 2 if self.terrace_side == 0 else self.wide - 10;
        void = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for z in [0, -6, b, self.far_z] {
            build.level(void, z);
        }
        # The island, the balcony over its back.
        deck(build, 1, 1, 14, self.wide - 1, 0, 3);
        deck(build, 1, 1, 6, self.wide - 1, b, 2);
        # Up to the balcony: a platform bobbing up a shaft through the
        # island beside it, or a pad.
        bs = self.wide - 6 if self.terrace_side == 0 else 2;
        throw(build, void, 10.0, py, 0, 3.0, py, b, None, [5, middle - 2, 6, middle + 3]);
        if self.bob {
            build.widen(void, 6, bs, -3, 10, bs + 4, 0);
            bobbing(build, void, 6, bs, 0, b, [0, 1, 3], [2]);
        }
        # The terrace down the island's side, its stair, and the pad from its
        # lip over the void to the far ledge.
        deck(build, 14, ty, 24, ty + 8, -6, 2);
        stair(build, 19, ty + 2, -6, 2, 6, 3);
        keep_box(build, void, 13, ty + 2, 14, ty + 5, 0);
        deck(build, self.long - 7, 1, self.long - 1, self.wide - 1, self.far_z, 3);
        throw(build, void, 21.0, float(ty) + 4.0, -6, float(self.long) - 3.5, float(ty) + 4.0, self.far_z, [23, ty + 2, 24, ty + 6], [self.long - 7, ty + 2, self.long - 6, ty + 6]);
        keep_box(build, void, 20, ty + 7, 23, ty + 8, -6);
        other_y = float(ty) + 12.0 if self.terrace_side == 0 else float(ty) - 4.0;
        void_pit(build, void, 1, 1, self.long - 1, self.wide - 1, low, [[25.5, float(ty) + 4.0, 20.5, float(ty) + 6.5, -6.0], [19.0, other_y, float(self.long) - 3.5, other_y, float(self.far_z)]], [[23, ty + 5, 24, ty + 8, -6], [self.long - 7, int(other_y) - 1, self.long - 6, int(other_y) + 2, self.far_z]]);
        build.doorway(void, self.enter);
        for port in self.taken {
            build.doorway(void, port);
        }
        build.start(2.5, py, 0, 0.0);
        build.supply(2.5, py - 2.0, 0, "ammo_shells", "q2");
        build.supply(3.0, float(self.wide) - float(bs) - 2.0, b, Q3_ARMOR, "q3");
        build.supply(22.0, float(ty) + 1.5, -6, "weapon_plasmagun", "q3");
        build.foe(3.5, py, b, apocalypse_foe(dice, self.danger, True), 0.0);
        build.foe(12.0, py, 0, apocalypse_foe(dice, self.danger), 180.0);
        build.foe(16.5, float(ty) + 6.0, -6, apocalypse_foe(dice, self.danger), 0.0);
        # From the terrace's lip, what holds the far ledge comes on.
        brink = build.touch(19.0, float(ty), -6.0, 24.0, float(ty + 8), 0.0);
        far_side = wake_later(build, brink, 1.5);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 2.5, 3.5 + float(index) * float(self.wide - 7), self.far_z, apocalypse_foe(dice, self.danger), 180.0, waits=far_side);
        }
        build.supply(float(self.long) - 3.5, py, self.far_z, Q3_HEALTH, "q3");
    }
}

"""Across the void two ways: a bobbing platform up to a high island and a
pad down from it, or a pad down to a low island and a bobbing platform up
from it."""
node BobbingCrossing(Prefab) {
    has deep: int = 14,
        side: int = 0,
        high_z: int = 9,
        far_z: int = 2,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bobbing crossing";
        self.source = Q3DM19;
        self.district = level_district(Q3DM19);
        self.long = dice.between(34, 36);
        self.wide = dice.between(20, 22);
        self.deep = 14;
        self.side = dice.below(2);
        self.high_z = dice.between(8, 10);
        self.far_z = [0, 2, 4][dice.below(3)];
        self.tall = self.high_z + 11;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.far_z), Port(face=1, along=float(self.long - 3), floor=self.far_z), Port(face=3, along=float(self.long - 3), floor=self.far_z)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -self.deep;
        hi = self.high_z;
        fz = self.far_z;
        void = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        for z in [0, -4, hi, fz] {
            build.level(void, z);
        }
        far = self.long - 7;
        deck(build, 1, 1, 8, self.wide - 1, 0, 3);
        deck(build, far, 1, self.long - 1, self.wide - 1, fz, 3);
        # The high way: bobbing up from the near ledge to the high island,
        # a pad from its end down to the far ledge.
        ay = 2 if self.side == 0 else self.wide - 6;
        bobbing(build, void, 8, ay, 0, hi, [2], [0]);
        deck(build, 12, ay - 1, 21, ay + 5, hi, 2);
        throw(build, void, 18.5, float(ay) + 2.0, hi, float(self.long) - 3.5, float(ay) + 2.0, fz, [20, ay, 21, ay + 4], [far, ay, far + 1, ay + 4]);
        # The low way: a pad down from the near ledge to the low island,
        # bobbing up from its end to the far ledge.
        low_y = self.wide - 8 if self.side == 0 else 2;
        deck(build, 13, low_y, far - 4, low_y + 6, -4, 2);
        throw(build, void, 5.0, float(low_y) + 3.0, 0, 16.0, float(low_y) + 3.0, -4, [7, low_y + 1, 8, low_y + 5], [13, low_y + 1, 14, low_y + 5]);
        bobbing(build, void, far - 4, low_y + 1, -4, fz, [2], [0]);
        keep_box(build, void, 17, low_y if self.side == 1 else low_y + 5, 20, low_y + 1 if self.side == 1 else low_y + 6, -4);
        # From the low island's middle, a pad back up to the high one.
        throw(build, void, 22.0, float(low_y) + 3.0, -4, 15.0, float(ay) + 2.0, hi, None, [13, ay - 1 if self.side == 1 else ay + 4, 21, ay if self.side == 1 else ay + 5]);
        void_pit(build, void, 1, 1, self.long - 1, self.wide - 1, low, [[16.0, py, 4.0, py, 0.0], [float(far) - 8.0, py, float(self.long) - 3.5, py, float(fz)]], [[7, middle - 1, 8, middle + 2, 0], [far, middle - 1, far + 1, middle + 2, fz]]);
        build.doorway(void, self.enter);
        for port in self.taken {
            build.doorway(void, port);
        }
        build.supply(15.0, float(ay) + 2.0, hi, Q3_ARMOR, "q3");
        build.foe(17.0, float(ay) + 3.5, hi, apocalypse_foe(dice, self.danger), 180.0);
        build.foe(float(far) - 8.0, float(low_y) + 1.5, -4, apocalypse_foe(dice, self.danger), 180.0, patrol=[[float(far) - 8.0, float(low_y) + 1.5], [17.0, float(low_y) + 1.5]]);
        build.supply(float(far) - 6.0, float(low_y) + 4.5, -4, "ammo_rockets", "q3");
        # Landing on the low island wakes what waits on the far ledge.
        landed = build.touch(13.0, float(low_y), -4.0, 18.0, float(low_y + 6), 2.0);
        far_side = wake_later(build, landed, 2.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 2.5, 3.5 + float(index) * float(self.wide - 7) / 2.0, fz, apocalypse_foe(dice, self.danger, index == 1), 180.0, waits=far_side);
        }
        build.supply(float(self.long) - 3.5, py, fz, Q3_HEALTH, "q3");
    }
}

"""A stair of floating stones winding up round a rock spire out of the
void, from the near ledge to a high ledge across the far end."""
node SpireStair(Prefab) {
    has steps: int = 16,
        start: int = 0,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Spire stair";
        self.source = Q3DM19;
        self.district = level_district(Q3DM19);
        self.long = dice.between(24, 26);
        self.wide = dice.between(22, 24);
        bx1 = self.long - 5;
        by1 = self.wide - 3;
        path = ring_path(9, 3, bx1, by1, 3);
        lap = len(path);
        # The stair starts at the ring's corner by the near ledge's -y end
        # or its +y end, and lands four cells along the far side.
        starts = [0, (bx1 - 9 - 3) + (by1 - 3 - 3) + (bx1 - 9 - 3)];
        self.start = starts[dice.below(2)];
        fits: list[int] = [];
        for steps in range(12, 31) {
            same = True;
            for index in range(4) {
                if path[(self.start + steps + index) % lap][4] != 0 {
                    same = False;
                }
            }
            if same {
                fits.append(steps);
            }
        }
        self.steps = fits[dice.below(len(fits))] if fits else 16;
        self.tall = self.steps + 10;
        self.low = -14;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.steps), Port(face=1, along=4.0, floor=0), Port(face=3, along=4.0, floor=0), Port(face=1, along=float(self.long - 2), floor=self.steps)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -13;
        bx1 = self.long - 5;
        by1 = self.wide - 3;
        void = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, 0);
        build.level(void, self.steps);
        build.level(void, self.steps // 2);
        # The near ledge and the short bridge from it to the stair's foot.
        deck(build, 1, 1, 7, self.wide - 1, 0, 3);
        foot_y = 3 if self.start == 0 else by1 - 3;
        deck(build, 7, foot_y, 9, foot_y + 3, 0, 3);
        # The spire, out of the void's floor, and the stair round it.
        build.solid(12, 6, low, bx1 - 3, by1 - 3, self.steps + 3);
        spiral(build, 9, 3, bx1, by1, 0, self.steps, 3, 4, self.start);
        # The high ledge across the far end, and a drop off it.
        deck(build, bx1, 1, self.long - 1, self.wide - 1, self.steps, 2);
        keep_box(build, void, bx1, 1, bx1 + 1, 3, self.steps);
        # The spire's top, a perch: a pad from the high ledge across to it,
        # one from it back down to the near ledge.
        perch = self.steps + 3;
        build.level(void, perch);
        sx = float(12 + bx1 - 3) * 0.5;
        throw(build, void, float(self.long) - 2.5, py, self.steps, sx, py, perch, [bx1, middle - 1, bx1 + 1, middle + 2], [bx1 - 4, middle - 1, bx1 - 3, middle + 2]);
        throw(build, void, sx - 1.0, py + 3.0, perch, 4.0, py + 3.0, 0, [12, middle + 2, 13, middle + 5], [6, middle + 2, 7, middle + 5]);
        build.supply(sx, py - 3.0, perch, "weapon_railgun", "q3");
        open_y = float(self.wide) - 2.0 if self.start == 0 else 2.0;
        void_pit(build, void, 1, 1, self.long - 1, self.wide - 1, low, [[8.0, open_y, 4.0, open_y, 0.0], [float(bx1) - 1.0, 2.0 if self.start == 0 else float(self.wide) - 2.0, 4.0, 2.0 if self.start == 0 else float(self.wide) - 2.0, 0.0]], [[6, int(open_y) - 1, 7, int(open_y) + 1, 0], [6, 1, 7, 4, 0], [6, self.wide - 4, 7, self.wide - 1, 0]]);
        build.doorway(void, self.enter);
        for port in self.taken {
            build.doorway(void, port);
        }
        path = ring_path(9, 3, bx1, by1, 3);
        lap = len(path);
        half = path[(self.start + self.steps // 2) % lap];
        hx = float(half[0] + half[2]) * 0.5;
        hy = float(half[1] + half[3]) * 0.5;
        build.foe(hx, hy, self.steps // 2 + 1, apocalypse_foe(dice, self.danger), 180.0);
        quarter = path[(self.start + self.steps // 4) % lap];
        build.supply(float(quarter[0] + quarter[2]) * 0.5, float(quarter[1] + quarter[3]) * 0.5, self.steps // 4 + 1, Q3_ARMOR, "q3");
        # Halfway up, the high ledge's guards come out.
        climbed = build.touch(float(half[0]), float(half[1]), float(self.steps // 2 + 1), float(half[2]), float(half[3]), float(self.steps // 2 + 7));
        guards = wake_later(build, climbed, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 2.5, 3.5 + float(index) * float(self.wide - 7) / 2.0, self.steps, apocalypse_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(4.0, 3.5, 0, apocalypse_foe(dice, self.danger), 0.0);
        build.supply(float(self.long) - 2.5, py, self.steps, Q3_HEALTH, "q3");
        build.supply(4.0, float(self.wide) - 3.5, 0, "ammo_cells", "q3");
    }
}

"""The hub: the great island, a keep in its middle thrown up to by pads
and a bobbing platform, bridges from its top out to high ways on."""
node ApocalypseKeep(Prefab) {
    has keep_top: int = 11,
        train_side: int = 0,
        two_pads: bool = False,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Apocalypse keep";
        self.source = Q3DM19;
        self.district = level_district(Q3DM19);
        self.long = dice.between(32, 34);
        self.wide = dice.between(28, 30);
        self.keep_top = dice.between(10, 12);
        self.train_side = dice.below(2);
        self.two_pads = dice.chance(0.5);
        self.tall = self.keep_top + 11;
        self.low = -15;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [
            Port(face=0, along=cy, floor=self.keep_top),
            Port(face=1 if self.train_side == 0 else 3, along=float(self.long // 2), floor=self.keep_top),
            Port(face=0, along=6.0, floor=0),
            Port(face=3 if self.train_side == 0 else 1, along=float(self.long - 7), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        kt = self.keep_top;
        low = -14;
        void = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, 0);
        build.level(void, kt);
        # The great island, the void along both its sides, a walk out to
        # the way on in one side wall.
        deck(build, 1, 4, self.long - 1, self.wide - 4, 0, 3);
        if self.train_side == 0 {
            deck(build, self.long - 9, 1, self.long - 5, 4, 0, 3);
        } else {
            deck(build, self.long - 9, self.wide - 4, self.long - 5, self.wide - 1, 0, 3);
        }
        # The keep, and the pads up to its top.
        build.solid(cx - 4, cy - 4, 0, cx + 4, cy + 4, kt);
        throw(build, void, float(cx) - 8.0, float(cy) + 0.5, 0, float(cx) - 1.5, float(cy) + 0.5, kt, None, [cx - 4, cy - 1, cx - 3, cy + 2]);
        if self.two_pads {
            throw(build, void, float(cx) + 8.0, float(cy) + 0.5, 0, float(cx) + 1.5, float(cy) + 0.5, kt, None, [cx + 3, cy - 1, cx + 4, cy + 2]);
        } else {
            # A pad from the island's far end up onto the far bridge.
            side_y = float(cy) + 5.5 if self.train_side == 0 else float(cy) - 4.5;
            throw(build, void, float(self.long) - 5.5, side_y, 0, float(self.long) - 5.5, float(cy) + 0.5, kt, None, [self.long - 8, cy - 2, self.long - 3, cy + 2]);
        }
        # The bobbing platform up one face of the keep, through the island.
        ty = cy - 8 if self.train_side == 0 else cy + 4;
        build.widen(void, cx - 2, ty, -3, cx + 2, ty + 4, 0);
        bobbing(build, void, cx - 2, ty, 0, kt, [0, 2, 3 if self.train_side == 0 else 1], [1 if self.train_side == 0 else 3]);
        # The bridges from the keep's top: out over the island and the void
        # to the far wall, and to the side wall away from the platform.
        deck(build, cx + 4, cy - 2, self.long - 1, cy + 2, kt, 2);
        if self.train_side == 0 {
            deck(build, cx - 2, cy + 4, cx + 2, self.wide - 1, kt, 2);
        } else {
            deck(build, cx - 2, 1, cx + 2, cy - 4, kt, 2);
        }
        void_pit(build, void, 1, 1, self.long - 1, self.wide - 1, low, [[6.0, 2.0, 6.0, 7.0, 0.0], [6.0, float(self.wide) - 2.0, 6.0, float(self.wide) - 7.0, 0.0]], [[5, 4, 8, 5, 0], [5, self.wide - 5, 8, self.wide - 4, 0]]);
        build.doorway(void, self.enter);
        for port in self.taken {
            build.doorway(void, port);
        }
        build.supply(float(cx) + 0.5, float(cy) + 0.5, kt, "item_quad", "q3");
        build.foe(float(cx) + 2.5, float(cy) - 2.5, kt, apocalypse_foe(dice, self.danger, True), 180.0);
        # A knight walks round the keep; others hold the island.
        walk_y = float(cy) + 6.5 if self.train_side == 0 else float(cy) - 6.0;
        build.foe(float(cx) - 6.5, walk_y, 0, "monster_knight", 0.0, patrol=[[float(cx) - 6.5, walk_y], [float(cx) + 6.5, walk_y]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 4.5, 6.5 + float(index) * float(self.wide - 13) / 2.0, 0, apocalypse_foe(dice, self.danger), 180.0);
        }
        # Up on the keep, what holds the bridges lets loose.
        landed = build.touch(float(cx - 4), float(cy - 4), float(kt), float(cx + 4), float(cy + 4), float(kt + 6));
        bridges = wake_later(build, landed, 1.0);
        build.foe(float(self.long) - 3.0, float(cy) + 0.5, kt, apocalypse_foe(dice, self.danger), 180.0, waits=bridges);
        build.foe(float(cx) + 0.5, float(self.wide) - 3.0 if self.train_side == 0 else 3.0, kt, apocalypse_foe(dice, self.danger), 270.0 if self.train_side == 0 else 90.0, waits=bridges);
        build.supply(4.0, float(cy) + 3.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(cy) + 1.5, kt, Q3_HEALTH, "q3");
        build.supply(4.0, float(cy) - 3.5, 0, "ammo_rockets", "q3");
    }
}

"""The key room: the key on an altar island high over the void, up by a
bobbing platform (or a pad) to a middle island and a pad on."""
node SkyAltar(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 20,
        mid_z: int = 6,
        altar_z: int = 12,
        side: int = 0,
        bob: bool = True,
        tall: int = 23;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sky altar (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM19;
        self.district = level_district(Q3DM19);
        self.long = dice.between(28, 30);
        self.hall_wide = dice.between(20, 22);
        self.wide = self.hall_wide + 4;
        self.mid_z = dice.between(5, 7);
        self.altar_z = dice.between(11, 13);
        self.side = dice.below(2);
        self.bob = dice.chance(0.6);
        self.tall = self.altar_z + 10;
        self.low = -15;
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
        low = -14;
        mz = self.mid_z;
        az = self.altar_z;
        room = build.room(1, 1, low, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        for z in [0, mz, az] {
            build.level(room, z);
        }
        build.doorway(room, self.enter);
        deck(build, 1, 1, 11, side, 0, 3);
        # The middle island, and the way up to it.
        my = 2 if self.side == 0 else side - 8;
        deck(build, 15, my, 21, my + 6, mz, 2);
        if self.bob {
            bobbing(build, room, 11, my + 1, 0, mz, [2], [0]);
        } else {
            throw(build, room, 8.0, float(my) + 3.0, 0, 17.0, float(my) + 3.0, mz, [10, my + 1, 11, my + 5], [15, my + 1, 16, my + 5]);
        }
        # The altar island, and the pad on to it.
        ay = side - 9 if self.side == 0 else 2;
        ax = self.long - 9;
        deck(build, ax, ay, self.long - 2, ay + 7, az, 2);
        keep_box(build, room, ax, ay, ax + 1, ay + 7, az);
        keep_box(build, room, ax, ay if self.side == 1 else ay + 6, self.long - 2, ay + 1 if self.side == 1 else ay + 7, az);
        throw(build, room, 19.5, float(my) + 3.0, mz, float(ax) + 3.5, float(ay) + 3.5, az, [20, my, 21, my + 6], None);
        build.teleporter(float(self.long) - 3.5, float(ay) + 5.5, az, 4.0, float(cy) + 0.5, 0, 0.0);
        void_pit(build, room, 1, 1, self.long - 1, side, low, [[13.0, float(cy) + 0.5, 6.0, float(cy) + 0.5, 0.0]], [[10, cy - 1, 11, cy + 2, 0]]);
        key_ambush(build, self.key, float(self.long) - 4.5, float(ay) + 2.0, az, side, 0, [2, 7], [apocalypse_foe(dice, self.danger, True), apocalypse_foe(dice, self.danger)]);
        build.foe(float(ax) + 2.0, float(ay) + 5.0, az, apocalypse_foe(dice, self.danger), 180.0);
        build.foe(18.0, float(my) + 1.5, mz, apocalypse_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(16.0, float(my) + 4.5, mz, "ammo_rockets", "q3");
    }
}

"""The end (or a gate): a hall, a deck out over the void, the way out on
an island across it, a pad over and by the seed a shuttle too."""
node VoidGate(Prefab) {
    has key: str = "",
        exit_z: int = 2,
        shuttle: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Void gate" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM19;
        self.district = level_district(Q3DM19);
        self.long = dice.between(32, 34);
        self.wide = dice.between(18, 20);
        self.shuttle = dice.chance(0.5);
        self.exit_z = 0 if self.shuttle else dice.between(2, 4);
        self.tall = 16;
        self.low = -15;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -14;
        wall = 7;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        void = build.room(wall + 1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, 0);
        build.level(void, self.exit_z);
        build.doorway(hall, self.enter);
        build.widen(void, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        ex = wall + 8;
        deck(build, wall + 1, 1, ex, self.wide - 1, 0, 3);
        ix = self.long - 9;
        deck(build, ix, middle - 4, self.long - 1, middle + 5, self.exit_z, 2);
        throw(build, void, float(ex) - 2.5, py - 3.0, 0, float(ix) + 3.0, py - 3.0, self.exit_z, [ex - 1, middle - 5, ex, middle - 1], [ix, middle - 5, ix + 1, middle - 1]);
        if self.shuttle {
            # A platform shuttling over the void between the deck and the
            # island, at the floor's height.
            build.train([4.0, 4.0, 1.0], [[float(ex), float(middle), -1.0], [float(ix) - 4.0, float(middle), -1.0]], 90.0, 2.0);
            keep_box(build, void, ex - 1, middle, ex, middle + 4, 0);
            keep_box(build, void, ix, middle, ix + 1, middle + 4, 0);
        }
        build.way_out(float(self.long) - 3.5, py + 1.0, self.exit_z);
        void_pit(build, void, wall + 1, 1, self.long - 1, self.wide - 1, low, [[float(ex) + 4.0, 3.0, float(ex) - 3.0, 3.0, 0.0]], [[ex - 1, 2, ex, 5, 0]]);
        door = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards = build.waiting();
        door +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(ix) + 2.5 + float(index % 2) * 2.0, py - 3.0 + float(index) * 3.0, self.exit_z, apocalypse_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, apocalypse_foe(dice, self.danger), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(ex) - 2.0, float(self.wide) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""q3dm19's stretches: [name, role]."""
glob Q3DM19_STRETCHES: list[list[str]] = [
         ["landing", "start"],
         ["crossing", "flow"],
         ["spire", "flow"],
         ["keep", "hub"],
         ["keep", "flow"],
         ["altar", "keyroom"],
         ["gate", "end"],
         ["gate", "gate"]
     ];

"""One of q3dm19's stretches by its name."""
def make_q3dm19(name: str, key: str) -> Prefab {
    if name == "landing" {
        return VoidLanding();
    }
    if name == "crossing" {
        return BobbingCrossing();
    }
    if name == "spire" {
        return SpireStair();
    }
    if name == "keep" {
        return ApocalypseKeep();
    }
    if name == "altar" {
        return SkyAltar(key=key if key else "key_silver");
    }
    return VoidGate(key=key);
}
