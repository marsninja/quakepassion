"""Prefabs drawn from Quake III's q3dm0, Introduction: a small arena to
learn in, two floors and a sunken pit, a teleporter up to a ledge, its
voice speaking at each threshold (q3dm0's triggers, timers and delays).
Quake III's arenas hold no foes of their own; q3dm0's are army, knight,
ogre. Raised in q3dm0's own palette.

- `IntroHall`: the start. A vestibule behind sliding doors (q3dm0's pair
  at its gate), then a hall with a gallery over an arcade along one wall
  (or round three), climbed by a stair, a lift or a jump pad; a hint at
  the threshold and again a moment later; ways on from the floor and the
  gallery.
- `IntroLoop`: a hall, a platform across its far end over an undercroft,
  reached by a teleporter at the near end, a stair up its side or a jump
  pad; a drop back down; ways on from the platform and the undercroft.
- `IntroPit`: the hub. A sunken pit inside a ring of floor, stairs down on
  two to four sides, a teleporter (or a jump pad) up from the pit to a
  balcony over the ring and a drop back; a second balcony now and then; a
  guard walking the ring; ways on from the ring and the balconies.
- `IntroSwitchback`: a deck over half a hall, a stair floating up the far
  wall and a bridge across to the deck (or a lift), the floor running on
  under both; ways on from the deck (forward or back over the way in) and
  from the floor under it.
- `IntroVault`: the key room. A gallery round three walls, the key on its
  far side, climbed by a stair, a lift or a jump pad; taking it opens the
  closets under the gallery.
- `IntroPortal`: the end (or a gate). The exit on a platform over an
  undercroft, thrown up to by a jump pad, climbed by a stair or reached
  by a teleporter; climbing to it brings a foe in by teleporter below."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush, gate_into, lift }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .q3low_parts { slab, keep_box, hint, wake_later, pad, flying_stair, sliding_pair, columns }

glob Q3DM0: str = "q3:q3dm0",
     Q3DM0_LIGHT: list[str] = ["monster_army", "monster_knight"],
     Q3DM0_HEAVY: list[str] = ["monster_ogre"];

"""A foe for q3dm0's stretches."""
def q3dm0_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    return arena_foe(dice, danger, Q3DM0_LIGHT, Q3DM0_HEAVY, strong);
}

"""The start: a vestibule behind sliding doors, a hall with a gallery over
an arcade, climbed by a stair, a lift or a jump pad."""
node IntroHall(Prefab) {
    has gallery: int = 7,
        access: int = 0,
        round: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Intro hall";
        self.source = Q3DM0;
        self.district = level_district(Q3DM0);
        self.long = dice.between(26, 30);
        self.wide = dice.between(16, 18);
        self.round = dice.chance(0.4);
        self.access = dice.below(3);
        self.gallery = dice.between(9, 10) if self.round else dice.between(6, 8);
        self.tall = self.gallery + 9;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=3.0, floor=self.gallery),
            Port(face=0, along=middle + 1.0, floor=0),
            Port(face=1, along=float(self.long - 5), floor=self.gallery if self.round else 0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gallery;
        vest = 7;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The vestibule's wall and the sliding pair in it.
        build.solid(vest, 1, 0, vest + 1, self.wide - 1, self.tall);
        build.widen(hall, vest, middle - 2, 0, vest + 1, middle + 2, 8);
        sliding_pair(build, vest, middle - 2, middle + 2, 0, 8);
        # The gallery along the -y wall over an arcade (and round the far
        # and +y walls).
        slab(build, vest + 1, 1, self.long - 1, 5, g);
        arcade_from = vest + 3;
        top_x = vest + 3 + g;
        if self.access == 0 {
            arcade_from = top_x + 2;
        }
        for x in range(arcade_from, self.long - 3, 4) {
            build.solid(x, 4, 0, x + 1, 5, g - 1);
        }
        if self.round {
            slab(build, self.long - 6, 5, self.long - 1, self.wide - 1, g);
            slab(build, vest + 1, self.wide - 5, self.long - 6, self.wide - 1, g);
            for x in range(vest + 3, self.long - 7, 4) {
                build.solid(x, self.wide - 5, 0, x + 1, self.wide - 4, g - 1);
            }
        }
        if self.access == 0 {
            # A stair up beside the gallery, its top stepping across onto it.
            stair(build, vest + 4, 5, 0, 0, g, 3);
            keep_box(build, hall, top_x - 1, 4, top_x + 2, 5, g);
        } elif self.access == 1 {
            lift(build, vest + 6, 5, vest + 9, 8, 0, g);
            keep_box(build, hall, vest + 6, 4, vest + 9, 5, g);
            keep_box(build, hall, vest + 5, 5, vest + 10, 9, 0);
        } else {
            px = vest + 6;
            pad(build, hall, float(px), 8.0, 0, float(px), 3.5, g, px - 2, 4, px + 2, 5);
        }
        # A stretch of the gallery's edge to drop from.
        keep_box(build, hall, self.long - 9, 4, self.long - 6, 5, g);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        # The arena's voice at the threshold, and again a moment on.
        hint(build, float(vest + 1), 5.0, 0.0, float(vest + 3), float(self.wide - 1), 6.0, "Welcome to the arena", "Fight your way to the exit", 2.5, "Up to the gallery for armor");
        # The gallery's guards wake as the player comes to the hall's middle.
        wake = build.touch(float(self.long // 2), 5.0, 0.0, float(self.long // 2 + 2), float(self.wide - 1), 6.0);
        guards = wake_later(build, wake, 1.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5 - float(index) * 4.0, 2.5, g, q3dm0_foe(dice, self.danger), 90.0, waits=guards);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(vest + 6 + index * 5) + 0.5, float(self.wide) - 3.5, 0, q3dm0_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long) - 4.5, float(middle) + 0.5, 0, q3dm0_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 3.0, 2.5, g, Q3_ARMOR, "q3");
        build.supply(float(vest) + 2.5, float(self.wide) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""A hall, a platform across its far end over an undercroft, reached by a
teleporter, a stair or a jump pad; ways on from both."""
node IntroLoop(Prefab) {
    has platform: int = 9,
        access: int = 0,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Intro loop";
        self.source = Q3DM0;
        self.district = level_district(Q3DM0);
        self.long = dice.between(22, 26);
        self.wide = dice.between(14, 16);
        self.platform = dice.between(9, 10);
        self.access = dice.below(3);
        self.tall = self.platform + 9;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle + 1.0, floor=self.platform),
            Port(face=1, along=float(self.long - 4), floor=self.platform),
            Port(face=0, along=3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        p = self.platform;
        px = self.long - 8;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, p);
        slab(build, px, 1, self.long - 1, self.wide - 1, p);
        # Pillars holding the platform's edge up, clear of the drop.
        for y in [4, self.wide - 8] {
            build.solid(px, y, 0, px + 1, y + 1, p - 1);
        }
        if self.access == 0 {
            build.teleporter(4.5, float(middle) + 0.5, 0, float(self.long) - 4.0, float(middle) + 0.5, p, 180.0);
            hint(build, 3.0, float(middle - 2), 0.0, 6.0, float(middle + 3), 6.0, "Teleporters carry you up", "Drop down from the platform's edge", 3.0, "Or take the way under it");
        } elif self.access == 1 {
            stair(build, px - p, 1, 0, 0, p, 3);
            keep_box(build, hall, px, 1, px + 1, 4, p);
            hint(build, 3.0, 1.0, 0.0, 5.0, float(self.wide - 1), 6.0, "The stair climbs to the platform", "Drop down from the platform's edge", 3.0, "Or take the way under it");
        } else {
            pad(build, hall, float(px) - 3.0, float(middle) + 0.5, 0, float(px) + 2.0, float(middle) + 0.5, p, px, middle - 2, px + 1, middle + 3);
            hint(build, float(px) - 6.0, 1.0, 0.0, float(px) - 5.0, float(self.wide - 1), 6.0, "Step on the pad to jump up", "Drop down from the platform's edge", 3.0, "Or take the way under it");
        }
        # The drop back down, at the platform's far side from the stair.
        keep_box(build, hall, px, self.wide - 5, px + 1, self.wide - 2, p);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The platform's guards wake as the player walks under it.
        under = build.touch(float(px + 1), 1.0, 0.0, float(px + 3), float(self.wide - 1), 6.0);
        above = wake_later(build, under, 0.5);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.0, 3.0 + float(index) * float(self.wide - 6), p, q3dm0_foe(dice, self.danger, index == 0), 180.0, waits=above);
        }
        build.foe(float(px) - 4.5, float(self.wide) - 3.0, 0, q3dm0_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, 0, q3dm0_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, p, Q3_HEALTH, "q3");
        build.supply(float(px) + 2.5, float(middle) + 0.5, 0, "ammo_nails");
    }
}

"""The hub: a sunken pit in a ring of floor, stairs down into it, a
teleporter or a jump pad up from it to a balcony over the ring."""
node IntroPit(Prefab) {
    has ring: int = 4,
        balcony: int = 11,
        sides: list[int] = [],
        teleport: bool = True,
        twin: bool = False,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Intro pit";
        self.source = Q3DM0;
        self.district = level_district(Q3DM0);
        self.long = dice.between(26, 28);
        self.wide = dice.between(24, 26);
        self.ring = 4;
        self.balcony = self.ring + dice.between(7, 8);
        self.tall = self.balcony + 9;
        self.teleport = dice.chance(0.5);
        self.twin = dice.chance(0.5);
        order = dice.order(4);
        self.sides = order[:dice.between(2, 4)];
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=self.ring);
        self.leaves = [
            Port(face=0, along=middle, floor=self.ring),
            Port(face=1, along=float(self.long // 2), floor=self.balcony),
            Port(face=3, along=float(self.long // 2), floor=self.balcony if self.twin else self.ring)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        r = self.ring;
        b = self.balcony;
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, r);
        build.level(hall, b);
        # The ring, and the pit sunk inside it.
        build.solid(1, 1, 0, self.long - 1, self.wide - 1, r);
        build.widen(hall, 6, 6, 0, self.long - 6, self.wide - 6, r);
        for side in self.sides {
            if side == 0 {
                stair(build, self.long - 6 - r, cy - 1, 0, 0, r, 3);
            } elif side == 2 {
                stair(build, 6 + r - 1, cy - 1, 0, 2, r, 3);
            } elif side == 1 {
                stair(build, cx + 2, self.wide - 6 - r, 0, 1, r, 3);
            } else {
                stair(build, cx + 2, 6 + r - 1, 0, 3, r, 3);
            }
        }
        # Columns at the ring's corners.
        columns(build, [[2, 2], [self.long - 3, 2], [2, self.wide - 3], [self.long - 3, self.wide - 3]], r, self.tall);
        # The balcony over the ring's +y side, and the way up to it from the
        # pit: a teleporter at its middle or a jump pad by its edge.
        slab(build, 6, self.wide - 6, self.long - 1, self.wide - 1, b);
        bx = 9;
        if self.teleport {
            build.teleporter(float(cx) - 2.0, float(cy) + 0.5, 0, float(bx) + 0.5, float(self.wide) - 3.0, b, 0.0);
        } else {
            pad(build, hall, float(bx), float(self.wide - 9), 0, float(bx), float(self.wide) - 4.0, b, bx - 2, self.wide - 6, bx + 2, self.wide - 5);
            keep_box(build, hall, bx - 2, self.wide - 6, bx + 2, self.wide - 5, r);
        }
        # The drop back to the ring.
        keep_box(build, hall, self.long - 10, self.wide - 6, self.long - 7, self.wide - 5, b);
        if self.twin {
            slab(build, 6, 1, self.long - 1, 6, b);
            pad(build, hall, float(bx), 9.0, 0, float(bx), 4.0, b, bx - 2, 5, bx + 2, 6);
            keep_box(build, hall, bx - 2, 5, bx + 2, 6, r);
            keep_box(build, hall, self.long - 10, 5, self.long - 7, 6, b);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        hint(build, 7.0, 7.0, 0.0, float(self.long - 7), float(self.wide - 7), 5.0, "The pit is a killing floor", "Get up to the balcony" if self.teleport else "The pad throws you up to the balcony", 2.0, "Mega health lies in the pit");
        # A guard walks the ring; the balcony's wake as the player reaches it.
        build.foe(3.5, 3.5, r, q3dm0_foe(dice, self.danger), 0.0, patrol=[[3.5, 3.5], [float(self.long) - 3.5, 3.5], [float(self.long) - 3.5, float(self.wide) - 3.5], [3.5, float(self.wide) - 3.5]]);
        up = build.touch(float(bx - 2), float(self.wide - 5), float(b), float(bx + 3), float(self.wide - 1), float(b + 6));
        above = wake_later(build, up, 0.5);
        build.foe(float(self.long) - 4.0, float(self.wide) - 3.0, b, q3dm0_foe(dice, self.danger, True), 180.0, waits=above);
        corners = [[7.5, 7.5], [float(self.long) - 7.5, float(self.wide) - 7.5], [float(self.long) - 7.5, 7.5], [7.5, float(self.wide) - 7.5]];
        for index in range(dice.between(2, 3)) {
            build.foe(corners[index][0], corners[index][1], 0, q3dm0_foe(dice, self.danger), 0.0);
        }
        build.foe(float(self.long) - 3.5, float(cy) + 4.5, r, q3dm0_foe(dice, self.danger, True), 180.0);
        build.supply(float(cx) + 3.5, float(self.wide) - 3.0, b, Q3_ARMOR, "q3");
        build.supply(float(cx) + 2.5, float(cy) + 0.5, 0, "item_health_mega", "q3");
        build.supply(3.5, float(self.wide) - 3.5, r, "ammo_shells", "q2");
    }
}

"""A deck over half a hall, a stair floating up the far wall and a bridge
across to it (or a lift), the floor running on under both."""
node IntroSwitchback(Prefab) {
    has deck: int = 9,
        access: int = 0,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Intro switchback";
        self.source = Q3DM0;
        self.district = level_district(Q3DM0);
        self.long = dice.between(22, 25);
        self.wide = dice.between(13, 15);
        self.deck = 9;
        self.access = dice.below(3);
        self.tall = self.deck + 10;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle + 1.0, floor=0);
        self.leaves = [
            Port(face=0, along=3.0, floor=self.deck),
            Port(face=0, along=middle + 1.0, floor=0),
            Port(face=2, along=3.0, floor=self.deck)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        d = self.deck;
        side = self.wide - 4;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, d);
        # The deck over the -y half.
        slab(build, 1, 1, self.long - 1, 6, d);
        if self.access == 0 {
            # Up the +y wall from the near end, a bridge across to the deck.
            flying_stair(build, 4, side, 0, 0, d, 3);
            top = 4 + d - 1;
            slab(build, top + 1, 6, top + 4, self.wide - 1, d);
            keep_box(build, hall, top + 1, 5, top + 4, 6, d);
        } elif self.access == 1 {
            # Up the +y wall from the far end, back toward the way in.
            start = self.long - 4;
            flying_stair(build, start, side, 0, 2, d, 3);
            top = start - d + 1;
            slab(build, top - 3, 6, top, self.wide - 1, d);
            keep_box(build, hall, top - 3, 5, top, 6, d);
        } else {
            lift(build, self.long - 10, 6, self.long - 7, 9, 0, d);
            keep_box(build, hall, self.long - 10, 5, self.long - 7, 6, d);
            keep_box(build, hall, self.long - 11, 6, self.long - 6, 10, 0);
        }
        # The deck's edge to drop from, by its far end.
        keep_box(build, hall, self.long - 5, 5, self.long - 2, 6, d);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The deck's guards wake a moment after the player sets foot on the
        # way up.
        foot = build.touch(3.0, float(side - 1), 0.0, 6.0, float(self.wide - 1), 6.0) if self.access == 0 else build.touch(float(self.long - 6), 6.0, 0.0, float(self.long - 2), float(self.wide - 1), 6.0);
        guards = wake_later(build, foot, 1.5);
        hint(build, 2.0, 1.0, 0.0, 4.0, float(self.wide - 1), 6.0, "The deck runs over the hall", "Climb to it", 2.5, "Or keep to the floor");
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 4.0 - float(index) * 6.0, 3.0, d, q3dm0_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(float(self.long // 2) + 0.5, 3.5, 0, q3dm0_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.5, float(self.wide) - 6.5, 0, q3dm0_foe(dice, self.danger), 180.0);
        build.supply(3.0, 3.0, d, Q3_HEALTH, "q3");
        build.supply(float(self.long // 2) - 2.5, 2.5, 0, "ammo_bullets", "q2");
    }
}

"""The key room: a gallery round three walls, the key on its far side,
climbed by a stair, a lift or a jump pad; taking it opens the closets under
the gallery."""
node IntroVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        gallery: int = 7,
        access: int = 0,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Intro vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM0;
        self.district = level_district(Q3DM0);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.gallery = dice.between(7, 8);
        self.access = dice.below(3);
        self.tall = self.gallery + 9;
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
        g = self.gallery;
        far = self.long - 6;
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, g);
        build.doorway(vault, self.enter);
        # The gallery round the -y, far and +y walls.
        slab(build, 6, 1, self.long - 1, 5, g);
        slab(build, far, 5, self.long - 1, side - 4, g);
        slab(build, 6, side - 4, self.long - 1, side, g);
        if self.access == 0 {
            stair(build, 6, 5, 0, 0, g, 3);
            keep_box(build, vault, 5 + g - 1, 4, 5 + g + 2, 5, g);
        } elif self.access == 1 {
            lift(build, far - 3, cy - 1, far, cy + 2, 0, g);
            keep_box(build, vault, far, cy - 1, far + 1, cy + 2, g);
            keep_box(build, vault, far - 4, cy - 2, far, cy + 3, 0);
        } else {
            pad(build, vault, float(far) - 3.0, float(cy) + 0.5, 0, float(far) + 1.5, float(cy) + 0.5, g, far, cy - 2, far + 1, cy + 3);
        }
        # An edge of the gallery to drop from.
        keep_box(build, vault, 13, 4, 16, 5, g);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, g, side, 0, [2, far - 5], [q3dm0_foe(dice, self.danger, True), q3dm0_foe(dice, self.danger)]);
        hint(build, 3.0, 1.0, 0.0, 5.0, float(side), 6.0, "The key lies on the gallery", "Its guards will come for it", 2.0, "Take it and fight your way back");
        build.foe(4.5, 3.0, 0, q3dm0_foe(dice, self.danger), 0.0, patrol=[[4.5, 3.0], [float(far) - 2.5, 3.0]]);
        build.foe(float(self.long) - 3.0, 3.0, g, q3dm0_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, float(side) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""The end (or a gate): the exit on a platform over an undercroft, thrown
up to by a jump pad, climbed by a stair, or reached by a teleporter."""
node IntroPortal(Prefab) {
    has key: str = "",
        platform: int = 6,
        access: int = 0,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Intro portal" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM0;
        self.district = level_district(Q3DM0);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.platform = dice.between(6, 7);
        self.access = dice.below(3);
        self.tall = self.platform + 10;
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 7;
        p = self.platform;
        px = self.long - 8;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(room, p);
        slab(build, px, 1, self.long - 1, self.wide - 1, p);
        if self.access == 0 {
            pad(build, room, float(px) - 3.0, float(middle) + 0.5, 0, float(px) + 2.0, float(middle) + 0.5, p, px, middle - 2, px + 1, middle + 3);
        } elif self.access == 1 {
            stair(build, px - p, 1, 0, 0, p, 3);
            keep_box(build, room, px, 1, px + 1, 4, p);
        } else {
            build.teleporter(float(wall) + 3.5, float(middle) + 0.5, 0, float(px) + 2.5, float(middle) + 0.5, p, 0.0);
        }
        build.way_out(float(self.long) - 4.0, float(middle), p);
        hint(build, float(wall + 1), 1.0, 0.0, float(wall + 3), float(self.wide - 1), 6.0, "The exit is on the platform", "Something stirs below", 3.0, "Hurry");
        # Reaching the platform brings a foe in below, by a teleporter sealed
        # under the floor.
        landing = build.touch(float(px), 1.0, float(p), float(px + 3), float(self.wide - 1), float(p + 6));
        coming = build.delay(1.0);
        landing +>:Fires:+> coming;
        coming +>:Fires:+> build.summon(wall + 3, 2, -8, q3dm0_foe(dice, self.danger, True), float(px) - 4.0, float(middle) + 0.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall + 6 + index * 4) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), 0, q3dm0_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.0, 2.5, p, q3dm0_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(px) + 2.5, float(self.wide) - 2.5, 0, Q3_ARMOR, "q3");
    }
}

"""q3dm0's stretches: [name, role]."""
glob Q3DM0_STRETCHES: list[list[str]] = [
         ["hall", "start"],
         ["loop", "flow"],
         ["switchback", "flow"],
         ["pit", "hub"],
         ["vault", "keyroom"],
         ["portal", "end"],
         ["portal", "gate"]
     ];

"""One of q3dm0's stretches by its name."""
def make_q3dm0(name: str, key: str) -> Prefab {
    if name == "hall" {
        return IntroHall();
    }
    if name == "loop" {
        return IntroLoop();
    }
    if name == "switchback" {
        return IntroSwitchback();
    }
    if name == "pit" {
        return IntroPit();
    }
    if name == "vault" {
        return IntroVault(key=key if key else "key_silver");
    }
    return IntroPortal(key=key);
}
