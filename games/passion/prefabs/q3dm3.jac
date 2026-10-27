"""Prefabs drawn from Quake III's q3dm3, Arena of Death: an arena under the
sky on three levels, a sunken court, the floor round it and walks high
over that, stairs between them everywhere and few railings, so a body
drops from any level to the one below and comes back up another way.
Quake III's arenas hold no foes of their own; q3dm3's are ogre, knight,
demon1. Raised in q3dm3's own palette.

- `DeathGate`: the start. A platform over a sunken court, a stair down
  its middle or two down its sides, a gallery high over the court's far
  end ridden up to by a lift or climbed along a wall; ways on from all
  three levels.
- `DeathTerraces`: three terraces stepping up an arena, two stairs
  between each, their edges open; a ledge high along a wall from the top
  terrace back over the lowest, dropped from at its end.
- `DeathRing`: the hub. A sunken court in a ring of floor, a walk high
  round the walls over the ring, stairs from the court on two to four
  sides and up to the walk at one or two corners, a bridge across the
  court high up; every edge open to drop from.
- `DeathCrossing`: a trench across the arena between two floors, a low
  bridge over it and stairs down into it, a high bridge over all of it
  climbed from either floor.
- `DeathPillar`: the key room. The key on a pillar standing in a moat,
  bridged from galleries along both walls (or one), the galleries climbed
  by stairs (or a stair and a lift); taking it opens the closets.
- `DeathArena`: the end (or a gate). A ledge over a sunken arena, the way
  out on a plinth in its middle, a walk high round its walls; the walk's
  guards wake as the player comes down."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, key_ambush, gate_into, lift }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .q3low_parts { slab, keep_box, keep_frame, hint, wake_later, flying_stair }

glob Q3DM3: str = "q3:q3dm3",
     Q3DM3_LIGHT: list[str] = ["monster_ogre", "monster_knight"],
     Q3DM3_HEAVY: list[str] = ["monster_demon1"],
     # The high walks' height over the floor (the floor's ways out under
     # them open six lifts high, clear of the walks' slabs).
     Q3DM3_HIGH: int = 7;

"""A foe for q3dm3's stretches."""
def q3dm3_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    return arena_foe(dice, danger, Q3DM3_LIGHT, Q3DM3_HEAVY, strong);
}

"""The start: a platform over a sunken court, stairs down, a gallery high
over the court's far end."""
node DeathGate(Prefab) {
    has sides: bool = False,
        access: int = 0,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Death gate";
        self.source = Q3DM3;
        self.district = level_district(Q3DM3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.sides = dice.chance(0.5);
        self.access = 0 if self.sides else dice.below(2);
        self.tall = Q3DM3_HIGH + 10;
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=Q3DM3_HIGH),
            Port(face=0, along=3.5, floor=-4),
            Port(face=1, along=5.0, floor=0),
            Port(face=1 if self.access == 1 else 3, along=float(self.long - 11), floor=-4)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        h = Q3DM3_HIGH;
        gx = self.long - 7;
        arena = build.room(1, 1, -4, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(arena, 0);
        build.level(arena, h);
        # The platform, its whole front open to drop from.
        build.solid(1, 1, -4, 10, self.wide - 1, 0);
        keep_box(build, arena, 9, 1, 10, self.wide - 1, 0);
        if self.sides {
            stair(build, 13, 1, -4, 2, 4, 3);
            stair(build, 13, self.wide - 4, -4, 2, 4, 3);
        } else {
            stair(build, 13, middle - 2, -4, 2, 4, 4);
        }
        # The gallery high over the court's far end.
        slab(build, gx, 1, self.long - 1, self.wide - 1, h);
        keep_box(build, arena, gx, 1, gx + 1, self.wide - 1, h);
        if self.access == 0 {
            lift(build, gx - 3, middle - 1, gx, middle + 2, -4, h);
            keep_box(build, arena, gx - 4, middle - 2, gx, middle + 3, -4);
        } else {
            stair(build, gx - h - 4, 1, -4, 0, h + 4, 3);
        }
        build.doorway(arena, self.enter);
        for port in self.taken {
            build.doorway(arena, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        hint(build, 5.0, 1.0, 0.0, 7.0, float(self.wide - 1), 6.0, "The Arena of Death", "Every floor drops to the one below", 2.5);
        rim = build.touch(8.0, 1.0, 0.0, 10.0, float(self.wide - 1), 6.0);
        court = wake_later(build, rim, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(16 + index * 3) + 0.5, float(middle) + (3.5 if index % 2 == 0 else -3.5), -4, q3dm3_foe(dice, self.danger), 180.0, waits=court);
        }
        build.foe(float(self.long) - 3.0, 3.0, h, q3dm3_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long) - 3.0, float(self.wide) - 3.0, h, q3dm3_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 3.0, float(middle) + 0.5, h, Q3_ARMOR, "q3");
        build.supply(float(gx) - 2.5, float(self.wide) - 3.0, -4, Q3_HEALTH, "q3");
        build.supply(4.5, float(middle) + 2.5, 0, "item_spikes");
        build.supply(float(gx) - 2.5, 3.0, -4, "item_rockets");
    }
}

"""Three terraces stepping up an arena, two stairs between each, a ledge
high along a wall from the top terrace back over the lowest."""
node DeathTerraces(Prefab) {
    has step_up: int = 3,
        ledge: bool = False,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Death terraces";
        self.source = Q3DM3;
        self.district = level_district(Q3DM3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.step_up = dice.between(3, 4);
        self.ledge = dice.chance(0.6);
        self.tall = 2 * self.step_up + 12;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        t1 = self.long // 3;
        t2 = 2 * self.long // 3;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=2 * self.step_up),
            Port(face=3 if self.ledge else 1, along=float(t1 + 2), floor=self.step_up),
            Port(face=3, along=3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        r = self.step_up;
        top = 2 * r;
        t1 = self.long // 3;
        t2 = 2 * self.long // 3;
        arena = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(arena, r);
        build.level(arena, top);
        build.solid(t1, 1, 0, self.long - 1, self.wide - 1, r);
        build.solid(t2, 1, 0, self.long - 1, self.wide - 1, top);
        # Two stairs up each terrace's face, the faces open to drop from.
        stair(build, t1 - r, 2, 0, 0, r, 3);
        if self.ledge {
            stair(build, t1 - r, middle - 1, 0, 0, r, 3);
        } else {
            stair(build, t1 - r, self.wide - 5, 0, 0, r, 3);
        }
        stair(build, t2 - r, middle - 1, r, 0, r, 3);
        if dice.chance(0.6) {
            stair(build, t2 - r, 2, r, 0, r, 3);
        }
        keep_box(build, arena, t1, 1, t1 + 1, self.wide - 1, r);
        keep_box(build, arena, t2, 1, t2 + 1, self.wide - 1, top);
        # The ledge high along the +y wall from the top terrace back over the
        # others, its near end open to drop from.
        if self.ledge {
            slab(build, 4, self.wide - 4, t1, self.wide - 1, top);
            build.solid(t1, self.wide - 4, 0, t2, self.wide - 1, top);
            keep_box(build, arena, 4, self.wide - 4, 5, self.wide - 1, top);
            keep_box(build, arena, 4, self.wide - 4, t1, self.wide - 3, top);
        }
        build.doorway(arena, self.enter);
        for port in self.taken {
            build.doorway(arena, port);
        }
        build.foe(float(t1) - 3.5, float(middle) + 3.5, 0, q3dm3_foe(dice, self.danger), 0.0);
        build.foe(float(t2) - 3.5, float(middle) + 3.5, r, q3dm3_foe(dice, self.danger), 180.0);
        build.foe(float(self.long) - 3.0, float(middle) + 3.5, top, q3dm3_foe(dice, self.danger, True), 180.0);
        if self.ledge {
            up = build.touch(float(t2), float(self.wide - 5), float(top), float(t2 + 2), float(self.wide - 1), float(top + 6));
            guard = wake_later(build, up, 0.5);
            build.foe(6.5, float(self.wide) - 2.5, top, q3dm3_foe(dice, self.danger), 0.0, waits=guard);
        }
        build.supply(float(self.long) - 2.5, 2.5, top, Q3_ARMOR, "q3");
        build.supply(float(t1) + 2.5, float(middle) + 0.5, r, Q3_HEALTH, "q3");
        build.supply(3.5, float(middle) + 0.5, 0, "item_spikes");
        build.supply(float(t2) + 2.5, float(middle) - 2.5, top, "item_health");
    }
}

"""The hub: a sunken court in a ring of floor, a walk high round the walls
over the ring, stairs from the court and up to the walk, a bridge across
the court high up; every edge open."""
node DeathRing(Prefab) {
    has sides: list[int] = [],
        ups: int = 0,
        bridge: bool = True,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Death ring";
        self.source = Q3DM3;
        self.district = level_district(Q3DM3);
        self.long = dice.between(30, 32);
        self.wide = dice.between(30, 32);
        order = dice.order(4);
        self.sides = order[:dice.between(2, 4)];
        self.ups = dice.below(3);
        self.bridge = self.ups > 0 or dice.chance(0.5);
        self.tall = Q3DM3_HIGH + 10;
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0, high=6);
        self.leaves = [
            Port(face=0, along=middle, floor=0, high=6),
            Port(face=1, along=float(self.long // 2), floor=Q3DM3_HIGH),
            Port(face=3, along=float(self.long // 2), floor=Q3DM3_HIGH),
            Port(face=0, along=float(self.wide) - 3.0, floor=Q3DM3_HIGH)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        h = Q3DM3_HIGH;
        cy = wide // 2;
        ring = build.room(1, 1, -4, long - 1, wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(ring, 0);
        build.level(ring, h);
        # The ring of floor, the court sunk inside it.
        build.solid(1, 1, -4, long - 1, wide - 1, 0);
        build.widen(ring, 8, 8, -4, long - 8, wide - 8, 0);
        for side in self.sides {
            if side == 0 {
                stair(build, long - 12, cy - 1, -4, 0, 4, 3);
            } elif side == 2 {
                stair(build, 11, cy - 1, -4, 2, 4, 3);
            } elif side == 1 {
                stair(build, 9, wide - 12, -4, 1, 4, 3);
            } else {
                stair(build, long - 12, 11, -4, 3, 4, 3);
            }
        }
        # The walk high round the walls.
        slab(build, 1, 1, long - 1, 5, h);
        slab(build, 1, wide - 5, long - 1, wide - 1, h);
        slab(build, 1, 5, 5, wide - 5, h);
        slab(build, long - 5, 5, long - 1, wide - 5, h);
        # Up to the walk: along the -y side, the +y side, or both.
        if self.ups != 2 {
            stair(build, 9, 5, 0, 0, h, 3);
        }
        if self.ups != 1 {
            stair(build, long - 10, wide - 8, 0, 2, h, 3);
        }
        if self.bridge {
            slab(build, 5, cy - 1, long - 5, cy + 2, h);
        }
        # Every edge open: the court's rim and the walk's.
        keep_frame(build, ring, 7, 7, long - 7, wide - 7, 0);
        keep_frame(build, ring, 4, 4, long - 4, wide - 4, h);
        build.doorway(ring, self.enter);
        for port in self.taken {
            build.doorway(ring, port);
        }
        # What lies in the court wakes as the player comes into it; a guard
        # walks the ring under the walk.
        down = build.touch(9.0, 9.0, -4.0, float(long - 9), float(wide - 9), 2.0);
        court = wake_later(build, down, 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(13 + index * 2) + 0.5, float(cy) + (3.5 if index % 2 == 0 else -3.5), -4, q3dm3_foe(dice, self.danger, index == 0), 0.0, waits=court);
        }
        build.foe(2.5, 2.5, 0, q3dm3_foe(dice, self.danger), 0.0, patrol=[[2.5, 2.5], [float(long) - 2.5, 2.5], [float(long) - 2.5, float(wide) - 2.5], [2.5, float(wide) - 2.5]]);
        walkers = wake_later(build, down, 2.0);
        build.foe(float(long) - 3.0, 3.0, h, q3dm3_foe(dice, self.danger, True), 180.0, waits=walkers);
        build.foe(3.0, float(wide) - 3.0, h, q3dm3_foe(dice, self.danger), 0.0, waits=walkers);
        build.supply(float(long // 2) + 0.5, float(cy) + 0.5, -4, "item_armor_combat", "q3");
        build.supply(3.0, 3.0, h, Q3_HEALTH, "q3");
        build.supply(float(long) - 3.0, float(wide) - 3.0, h, Q3_HEALTH, "q3");
        build.supply(float(long // 2) + 0.5, 3.0, h, "weapon_rocketlauncher");
        build.supply(float(long // 2) - 1.5, 3.0, h, "item_rockets");
        build.supply(3.0, float(cy) + 3.5, 0, "item_rockets");
        build.supply(float(long) - 3.0, float(cy) - 3.5, 0, "item_health");
    }
}

"""A trench across an arena between two floors, a low bridge over it and
stairs down into it, a high bridge over all of it climbed from either
floor."""
node DeathCrossing(Prefab) {
    has low_bridge: bool = True,
        both: bool = True,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Death crossing";
        self.source = Q3DM3;
        self.district = level_district(Q3DM3);
        self.long = dice.between(24, 26);
        self.wide = dice.between(24, 26);
        self.low_bridge = dice.chance(0.6);
        self.both = dice.chance(0.6);
        self.tall = Q3DM3_HIGH + 10;
        self.low = -5;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle + 2), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide) - 4.0, floor=0),
            Port(face=3, along=float(self.long // 2), floor=-4),
            Port(face=1, along=4.0, floor=0),
            Port(face=0, along=float(middle + 1), floor=Q3DM3_HIGH)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        long = self.long;
        wide = self.wide;
        middle = wide // 2;
        h = Q3DM3_HIGH;
        arena = build.room(1, 1, -4, long - 1, wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(arena, 0);
        build.level(arena, h);
        # The floors either side of the trench.
        build.solid(1, 1, -4, 9, wide - 1, 0);
        build.solid(long - 9, 1, -4, long - 1, wide - 1, 0);
        keep_box(build, arena, 8, 1, 9, wide - 1, 0);
        keep_box(build, arena, long - 9, 1, long - 8, wide - 1, 0);
        # Stairs down into the trench from both floors.
        stair(build, 12, wide - 6, -4, 2, 4, 4);
        stair(build, long - 13, wide - 6, -4, 0, 4, 4);
        if self.low_bridge {
            slab(build, 9, 2, long - 9, 5, 0);
        }
        # The high bridge, four cells wide, from over the near floor to the
        # far wall, climbed from the near floor (and the far one).
        slab(build, 3, middle - 1, long - 1, middle + 3, h);
        flying_stair(build, 3, middle - 1 - h, 0, 1, h, 3);
        if self.both {
            flying_stair(build, long - 6, middle + 3 + h - 1, 0, 3, h, 3);
        }
        keep_box(build, arena, 3, middle - 1, 4, middle + 3, h);
        keep_box(build, arena, 9, middle - 1, long - 9, middle, h);
        build.doorway(arena, self.enter);
        for port in self.taken {
            build.doorway(arena, port);
        }
        # The trench's foes wake as the player sets foot on a bridge.
        over = build.touch(float(long // 2 - 1), 2.0, 0.0, float(long // 2 + 1), 5.0, 6.0) if self.low_bridge else build.touch(float(long // 2 - 1), float(middle - 1), float(h), float(long // 2 + 1), float(middle + 3), float(h + 6));
        trench = wake_later(build, over, 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(long // 2) + 0.5, 7.5 + float(index) * 3.0, -4, q3dm3_foe(dice, self.danger, index == 0), 90.0, waits=trench);
        }
        build.foe(float(long) - 4.5, 4.5, 0, q3dm3_foe(dice, self.danger), 180.0);
        build.foe(float(long) - 3.0, float(middle) + 1.0, h, q3dm3_foe(dice, self.danger, True), 180.0);
        build.supply(float(long // 2) + 0.5, float(wide) - 3.0, -4, Q3_HEALTH, "q3");
        build.supply(float(long // 2) + 0.5, float(middle) + 1.0, h, "item_armor_shard", "q3");
        build.supply(4.5, 4.5, 0, "item_shells");
        build.supply(float(long) - 4.5, float(wide) - 3.0, 0, "item_health");
    }
}

"""The key room: the key on a pillar standing in a moat, bridged from
galleries along both walls (or one), the galleries climbed by stairs (or a
stair and a lift)."""
node DeathPillar(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        bridges: int = 2,
        lifted: bool = False,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Death pillar (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM3;
        self.district = level_district(Q3DM3);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.bridges = dice.between(1, 2);
        self.lifted = dice.chance(0.4);
        self.tall = Q3DM3_HIGH + 10;
        self.low = -5;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        h = Q3DM3_HIGH;
        cx = self.long // 2;
        cy = side // 2;
        hall = build.room(1, 1, -4, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        build.level(hall, 0);
        build.level(hall, h);
        build.doorway(hall, self.enter);
        # The floor, the moat sunk round the pillar, steps up out of it.
        build.solid(1, 1, -4, self.long - 1, side, 0);
        build.widen(hall, cx - 5, cy - 4, -4, cx + 6, cy + 5, 0);
        stair(build, cx - 2, cy - 4, -4, 2, 4, 3);
        stair(build, cx + 2, cy + 2, -4, 0, 4, 3);
        build.solid(cx - 2, cy - 1, -4, cx + 3, cy + 2, h);
        keep_frame(build, hall, cx - 6, cy - 5, cx + 7, cy + 6, 0);
        # The galleries along both walls, climbed from the near end.
        gs = 2 + h;
        slab(build, gs, 1, self.long - 1, 4, h);
        slab(build, gs, side - 3, self.long - 1, side, h);
        flying_stair(build, 2, 1, 0, 0, h, 3);
        if self.lifted {
            lift(build, 2, side - 6, 5, side - 3, 0, h);
            slab(build, 2, side - 3, gs, side, h);
            keep_box(build, hall, 2, side - 3, 5, side - 2, h);
            keep_box(build, hall, 1, side - 7, 6, side - 3, 0);
        } else {
            flying_stair(build, 2, side - 3, 0, 0, h, 3);
        }
        # The bridges from the galleries to the pillar's top.
        slab(build, cx - 1, 4, cx + 2, cy - 1, h);
        if self.bridges == 2 {
            slab(build, cx - 1, cy + 2, cx + 2, side - 3, h);
        }
        keep_box(build, hall, gs + 1, 3, gs + 4, 4, h);
        key_ambush(build, self.key, float(cx) + 0.5, float(cy) + 0.5, h, side, 0, [gs + 1, self.long - 6], [q3dm3_foe(dice, self.danger, True), q3dm3_foe(dice, self.danger)]);
        hint(build, 2.0, 4.0, 0.0, 4.0, float(side - 3), 6.0, "The key stands on the pillar", "Cross to it from the galleries", 2.0);
        spots = [[float(cx) - 4.5, float(cy) + 3.5], [float(cx) + 0.5, float(cy) + 3.5], [float(cx) + 4.5, float(cy) - 2.5]];
        for index in range(dice.between(2, 3)) {
            build.foe(spots[index][0], spots[index][1], -4, q3dm3_foe(dice, self.danger), 90.0);
        }
        build.foe(float(self.long) - 3.0, 2.5, h, q3dm3_foe(dice, self.danger, True), 180.0);
        build.supply(float(self.long) - 3.0, float(side) - 2.0, h, Q3_HEALTH, "q3");
        build.supply(3.0, float(side) - 6.0, 0, "item_health");
        build.supply(float(cx) - 1.0, float(cy) + 0.5, h, "item_rockets");
    }
}

"""The end (or a gate): a ledge over a sunken arena, the way out on a
plinth in its middle, a walk high round its walls."""
node DeathArena(Prefab) {
    has key: str = "",
        sides: bool = False,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Death arena" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM3;
        self.district = level_district(Q3DM3);
        self.long = dice.between(35, 37);
        self.wide = dice.between(20, 22);
        self.sides = dice.chance(0.5);
        self.tall = Q3DM3_HIGH + 10;
        self.low = -5;
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
        rim = wall + 6;
        h = Q3DM3_HIGH;
        cx = rim + 10;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, -4, self.tall, self.key, True);
        build.level(room, h);
        build.solid(wall + 1, 1, -4, rim, self.wide - 1, 0);
        keep_box(build, room, rim - 1, 1, rim, self.wide - 1, 0);
        if self.sides {
            stair(build, rim + 3, 1, -4, 2, 4, 3);
            stair(build, rim + 3, self.wide - 4, -4, 2, 4, 3);
        } else {
            stair(build, rim + 3, middle - 2, -4, 2, 4, 4);
        }
        # The walk high round the arena's three far walls, a stair up to it
        # from the arena's floor.
        slab(build, rim, 1, self.long - 1, 5, h);
        slab(build, rim, self.wide - 5, self.long - 1, self.wide - 1, h);
        slab(build, self.long - 5, 5, self.long - 1, self.wide - 5, h);
        stair(build, self.long - 8, self.wide - 5 - h - 4, -4, 1, h + 4, 3);
        keep_frame(build, room, rim, 4, self.long - 4, self.wide - 4, h);
        # The plinth in the arena's middle, steps up its four sides, the way
        # out on it.
        build.solid(cx - 3, middle - 3, -4, cx + 3, middle + 3, -3);
        build.solid(cx - 2, middle - 2, -3, cx + 2, middle + 2, -2);
        build.solid(cx - 1, middle - 1, -2, cx + 1, middle + 1, -1);
        build.way_out(float(cx), float(middle), -1);
        down = build.touch(float(rim), 5.0, -4.0, float(rim + 4), float(self.wide - 5), 2.0);
        walk = wake_later(build, down, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.0, 3.0 + float(index) * float(self.wide - 6) * 0.5, h, q3dm3_foe(dice, self.danger, index == 0), 180.0, waits=walk);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx) - 5.5, 7.5 + float(index) * 3.0, -4, q3dm3_foe(dice, self.danger), 180.0);
        }
        build.foe(float(wall) + 3.5, 3.0, 0, q3dm3_foe(dice, self.danger), 0.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(rim) + 2.5, 3.0, h, "item_armor_body", "q3");
        build.supply(float(wall) + 2.5, float(self.wide) - 3.0, 0, "item_rockets");
        build.supply(float(rim) + 2.5, float(middle) + 3.5, -4, "item_health");
    }
}

"""q3dm3's stretches: [name, role]."""
glob Q3DM3_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["terraces", "flow"],
         ["crossing", "flow"],
         ["ring", "hub"],
         ["pillar", "keyroom"],
         ["arena", "end"],
         ["arena", "gate"]
     ];

"""One of q3dm3's stretches by its name."""
def make_q3dm3(name: str, key: str) -> Prefab {
    if name == "gate" {
        return DeathGate();
    }
    if name == "terraces" {
        return DeathTerraces();
    }
    if name == "crossing" {
        return DeathCrossing();
    }
    if name == "ring" {
        return DeathRing();
    }
    if name == "pillar" {
        return DeathPillar(key=key if key else "key_silver");
    }
    return DeathArena(key=key);
}
