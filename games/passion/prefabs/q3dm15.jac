"""Prefabs drawn from Quake III's q3dm15, Demon Keep: a gothic keep across a
moat, its halls three tiers deep (nave, aisles and balconies, the original's
stacked floors at -128, -64, 0 and 192), a pit of blades crossed by a
narrow bridge (its pendulums over a hurting pit, here blades shot across
the bridge on timers), a throne on a dais thrown up from to the galleries,
and jump pads everywhere. Quake III's arenas hold no foes of their own;
q3dm15's are knights and hell knights, fiends as a run goes deeper.

- `DemonGate`: the start. A hall, a moat of water across the room, a
  drawbridge lowered by a button (or a bridge), a forecourt, the keep's
  floor raised over an undercroft at the far end, up a stair or a pad.
- `DemonBladePit`: platforms at both ends of a deep hurting pit, a narrow
  bridge between them (broken in its middle now and then) swept by blades
  on timers; a gallery over the pit a pad throws a body up to; a pad and a
  teleporter out of the pit.
- `DemonHall`: three tiers: a nave, aisles over its sides and balconies
  over the aisles; a stair down into the nave, pads up to the aisles,
  stairs up to the balconies, a teleporter now and then.
- `DemonThrone`: the hub. A dais in the middle of a hall, a stair up it and
  pads from its top up to galleries along both walls, a hurting pit behind
  it with a pad out, a teleporter from a gallery back down.
- `DemonAltar`: the key room. The key on an altar behind a hurting pit,
  thrown over to by a pad, or reached over a bridge swept by blades and up
  a lift. Taking it opens the closets.
- `DemonSanctum`: the end (or a gate). A ledge along one wall up a stair or
  a pad, a balcony across the far wall a pad on the ledge throws a body up
  to, the way out on the balcony; a hurting pit in the floor."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .common { stair, gate_into, lift }
import from .q3arena { arena_foe, Q3_HEALTH, Q3_ARMOR }
import from .q3tiers { keep_box, deck, key_taken, pit_fall, pad_to, closets, wake_on }

glob Q3DM15: str = "q3:q3dm15",
     Q3DM15_LIGHT: list[str] = ["monster_knight", "monster_hell_knight"],
     Q3DM15_HEAVY: list[str] = ["monster_demon1"];

"""A foe for the Demon Keep."""
def demon_foe(dice: Stream, danger: float, strong: bool = False) -> str {
    return arena_foe(dice, danger, Q3DM15_LIGHT, Q3DM15_HEAVY, strong);
}

"""Blades across a way (the cell line y = `line`, shot the way `out` goes,
1 +y or 3 -y) at each of `xs`, `z` lifts up, each on a timer of its own."""
def blades(build: Raising, xs: list[int], line: float, z: float, out: int) {
    for (index, x) in enumerate(xs) {
        build.timer(2.0 + float(index)) +>:Fires:+> build.spikes(float(x) + 0.5, line, z, out);
    }
}

"""The start: a hall, a moat with a drawbridge, a forecourt, the keep's
raised floor."""
node DemonGate(Prefab) {
    has drawbridge: bool = True,
        padded: bool = False,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Demon gate";
        self.source = Q3DM15;
        self.district = level_district(Q3DM15);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(18, 19);
        self.drawbridge = dice.chance(0.6);
        self.padded = dice.chance(0.4);
        self.low = -12;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=9),
            Port(face=0, along=3.0, floor=0),
            Port(face=1, along=16.0, floor=0),
            Port(face=3, along=float(self.long - 4), floor=9)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        kx = self.long - 8;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(hall, 9);
        # The moat across the room, and its bridge: drawn down when the
        # button by it is pressed, or standing.
        build.pool(9, 1, -5, 13, self.wide - 1, 0, 2, False, True, True);
        if self.drawbridge {
            press = build.push(7.5, float(self.wide - 1), 3.0, 3);
            press +>:Fires:+> build.drawn(9.0, float(mid - 2), 13.0, float(mid + 2), 0, 6);
        } else {
            deck(build, 9, mid - 2, 13, mid + 2, 0);
        }
        keep_box(build, hall, 8, mid - 2, 9, mid + 2, 0);
        keep_box(build, hall, 13, mid - 2, 14, mid + 2, 0);
        # The keep's floor raised over its undercroft, up a stair along its
        # front or a pad.
        deck(build, kx, 1, self.long - 1, self.wide - 1, 9);
        for y in range(3, self.wide - 2, 4) {
            build.solid(kx, y, 0, kx + 1, y + 1, 8);
        }
        if self.padded {
            pad_to(build, float(kx - 3), float(mid) + 0.5, 0, float(kx) + 3.0, float(mid) + 0.5, 9);
            keep_box(build, hall, kx, mid - 1, kx + 1, mid + 2, 9);
        } else {
            stair(build, kx - 3, 1, 0, 1, 9, 3);
            keep_box(build, hall, kx, 6, kx + 1, 11, 9);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.start(2.5, float(mid) + 0.5, 0, 0.0);
        build.supply(2.5, float(mid) - 1.5, 0, "ammo_shells", "q2");
        # Over the moat, the forecourt's guards wake.
        court = wake_on(build, 13.0, 1.0, 15.0, float(self.wide - 1), 0.0);
        build.foe(float(kx) - 3.5, 3.5, 0, demon_foe(dice, self.danger), 180.0, waits=court);
        build.foe(float(kx) - 3.5, float(self.wide) - 3.5, 0, demon_foe(dice, self.danger), 180.0, waits=court);
        build.foe(float(self.long) - 3.5, float(mid) + 0.5, 9, demon_foe(dice, self.danger, True), 180.0);
        build.foe(5.5, float(mid) + 3.5, 0, "monster_knight", 0.0);
        build.foe(float(kx) + 2.5, 2.5, 0, "monster_knight", 90.0, patrol=[[float(kx) + 2.5, 2.5], [float(kx) + 2.5, float(self.wide) - 2.5]]);
        build.supply(float(self.long) - 3.0, 3.0, 9, Q3_ARMOR, "q3");
        build.supply(16.0, float(mid) + 0.5, 0, Q3_HEALTH, "q3");
    }
}

"""Platforms at both ends of a deep hurting pit, a bridge between them swept
by blades, a gallery over the pit, a pad and a teleporter out."""
node DemonBladePit(Prefab) {
    has broken: bool = False,
        count: int = 2,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Demon blade pit";
        self.source = Q3DM15;
        self.district = level_district(Q3DM15);
        self.long = dice.between(30, 34);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(17, 18);
        self.broken = dice.chance(0.4);
        self.count = dice.between(2, 3);
        self.low = -15;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        cx = self.long // 2;
        hall = build.room(1, 1, -14, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        build.level(hall, 8);
        build.solid(1, 1, -14, 7, self.wide - 1, 0);
        build.solid(self.long - 7, 1, -14, self.long - 1, self.wide - 1, 0);
        # The bridge, broken in its middle now and then.
        if self.broken {
            deck(build, 7, mid - 1, cx, mid + 2, 0);
            deck(build, cx + 1, mid - 1, self.long - 7, mid + 2, 0);
            keep_box(build, hall, cx - 1, mid - 1, cx, mid + 2, 0);
            keep_box(build, hall, cx + 1, mid - 1, cx + 2, mid + 2, 0);
        } else {
            deck(build, 7, mid - 1, self.long - 7, mid + 2, 0);
        }
        keep_box(build, hall, 6, mid - 1, 7, mid + 2, 0);
        keep_box(build, hall, self.long - 7, mid - 1, self.long - 6, mid + 2, 0);
        # The blades across it, on their timers.
        span = (self.long - 20) // max(1, self.count - 1);
        blades(build, [10 + index * span for index in range(self.count)], 1.2, 1.0, 1);
        # The pit's floor burns; what waits on the far platform wakes at a
        # fall or halfway over.
        guards = build.waiting();
        pit_fall(build, 7, 1, self.long - 7, self.wide - 1, -14, "The pit's floor burns", guards);
        halfway = build.touch(float(cx - 1), float(mid - 1), 0.0, float(cx + 2), float(mid + 2), 6.0);
        halfway +>:Fires:+> guards;
        pad_to(build, float(self.long - 10), 3.5, -14, float(self.long) - 4.0, 3.5, 0);
        keep_box(build, hall, self.long - 7, 2, self.long - 6, 6, 0);
        build.teleporter(12.0, 3.5, -14, 3.5, 3.5, 0, 0.0);
        # The gallery over the pit along the north wall, a pad up to it from
        # the near platform, dropped off at its far end.
        deck(build, 7, self.wide - 5, self.long - 7, self.wide - 1, 8);
        pad_to(build, 4.0, float(self.wide) - 3.0, 0, 8.5, float(self.wide) - 3.0, 8);
        keep_box(build, hall, 7, self.wide - 5, 8, self.wide - 1, 8);
        keep_box(build, hall, self.long - 8, self.wide - 5, self.long - 7, self.wide - 1, 8);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        build.foe(float(self.long) - 3.5, float(mid) + 2.5, 0, demon_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(self.long) - 3.5, float(mid) - 2.5, 0, demon_foe(dice, self.danger), 180.0, waits=guards);
        build.foe(float(cx) + 0.5, float(self.wide) - 3.0, 8, demon_foe(dice, self.danger), 270.0);
        build.foe(float(cx) + 0.5, 4.5, -14, "monster_knight", 0.0);
        build.foe(4.5, 3.5, 0, demon_foe(dice, self.danger), 0.0);
        build.supply(float(cx) + 3.5, float(self.wide) - 3.0, 8, Q3_ARMOR, "q3");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""Three tiers: a nave, aisles over its sides, balconies over the aisles."""
node DemonHall(Prefab) {
    has warp: bool = False,
        tall: int = 17;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Demon hall";
        self.source = Q3DM15;
        self.district = level_district(Q3DM15);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(17, 18);
        self.warp = dice.chance(0.5);
        self.low = -10;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long - 3), floor=-9),
            Port(face=1, along=float(self.long // 2), floor=8),
            Port(face=3, along=float(self.long // 2), floor=8)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        lo = -9;
        mid = self.wide // 2;
        hall = build.room(1, 1, lo, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 0);
        build.level(hall, 8);
        # The landings at both ends, the aisles over the nave's sides, the
        # balconies over the aisles.
        build.solid(1, 1, lo, 6, self.wide - 1, 0);
        build.solid(self.long - 6, 1, lo, self.long - 1, self.wide - 1, 0);
        build.widen(hall, self.long - 6, 1, lo, self.long - 1, 5, -2);
        deck(build, 6, 1, self.long - 6, 7, 0);
        deck(build, 6, self.wide - 7, self.long - 6, self.wide - 1, 0);
        deck(build, 1, 1, self.long - 1, 4, 8);
        deck(build, 1, self.wide - 4, self.long - 1, self.wide - 1, 8);
        for x in range(8, self.long - 15, 5) {
            build.solid(x, 3, 0, x + 1, 4, 7);
            build.solid(x, self.wide - 4, 0, x + 1, self.wide - 3, 7);
        }
        # Down into the nave at its east end; pads up to the aisles at its
        # west; stairs up from the aisles to the balconies at the east.
        stair(build, self.long - 14, mid - 1, lo, 0, 9, 3);
        pad_to(build, 9.0, 10.0, lo, 9.0, 5.5, 0);
        keep_box(build, hall, 8, 6, 11, 7, 0);
        pad_to(build, 12.0, float(self.wide - 10), lo, 12.0, float(self.wide) - 5.5, 0);
        keep_box(build, hall, 11, self.wide - 7, 14, self.wide - 6, 0);
        stair(build, self.long - 14, 4, 0, 0, 8, 3);
        keep_box(build, hall, self.long - 8, 3, self.long - 5, 4, 8);
        stair(build, self.long - 14, self.wide - 7, 0, 0, 8, 3);
        keep_box(build, hall, self.long - 8, self.wide - 4, self.long - 5, self.wide - 3, 8);
        if self.warp {
            build.teleporter(3.0, float(self.wide) - 2.5, 8, float(self.long // 2) - 2.0, float(mid) + 0.5, lo, 0.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # At the nave stair's foot, the aisles' guards wake.
        foot = wake_on(build, float(self.long - 15), float(mid - 1), float(self.long - 12), float(mid + 2), float(lo));
        build.foe(float(self.long // 2) + 0.5, 5.5, 0, demon_foe(dice, self.danger), 270.0, waits=foot);
        build.foe(float(self.long // 2) - 2.5, float(self.wide) - 5.5, 0, demon_foe(dice, self.danger), 90.0, waits=foot);
        build.foe(float(self.long // 2) + 0.5, 2.5, 8, demon_foe(dice, self.danger, True), 90.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(16 + index * 3) + 0.5, float(mid) + (2.5 if index % 2 == 0 else -2.5), lo, demon_foe(dice, self.danger), 180.0);
        }
        build.foe(7.5, float(mid) - 2.5, lo, "monster_knight", 0.0, patrol=[[7.5, float(mid) - 2.5], [float(self.long) - 16.5, float(mid) - 2.5]]);
        build.supply(float(self.long // 2) + 0.5, float(mid) + 0.5, lo, Q3_ARMOR, "q3");
        build.supply(3.0, 2.5, 8, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(mid) + 0.5, 0, Q3_HEALTH, "q3");
    }
}

"""The hub: a dais in a hall, pads from its top to galleries along both
walls, a hurting pit behind it, a teleporter back down."""
node DemonThrone(Prefab) {
    has tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Demon throne";
        self.source = Q3DM15;
        self.district = level_district(Q3DM15);
        self.long = dice.between(30, 32);
        self.wide = dice.between(26, 28);
        self.tall = dice.between(22, 23);
        self.low = -9;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        cx = float(self.long // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [
            Port(face=0, along=cy, floor=0),
            Port(face=1, along=cx, floor=12),
            Port(face=3, along=cx - 6.0, floor=12),
            Port(face=1, along=5.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        gal = 12;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 6);
        build.level(hall, gal);
        # The dais and its stair.
        build.solid(cx - 5, cy - 5, 0, cx + 5, cy + 5, 6);
        stair(build, cx - 11, cy - 1, 0, 0, 6, 3);
        # The galleries on their arcades, pads up to them from the dais.
        deck(build, 1, 1, self.long - 1, 5, gal);
        deck(build, 1, self.wide - 5, self.long - 1, self.wide - 1, gal);
        for x in range(4, self.long - 3, 4) {
            if x < cx - 2 or x > cx + 2 {
                build.solid(x, 4, 0, x + 1, 5, gal - 1);
                build.solid(x, self.wide - 5, 0, x + 1, self.wide - 4, gal - 1);
            }
        }
        pad_to(build, float(cx), float(cy - 2), 6, float(cx), 3.0, gal);
        keep_box(build, hall, cx - 1, 4, cx + 2, 5, gal);
        pad_to(build, float(cx), float(cy + 2), 6, float(cx), float(self.wide) - 3.0, gal);
        keep_box(build, hall, cx - 1, self.wide - 5, cx + 2, self.wide - 4, gal);
        keep_box(build, hall, 3, 4, 6, 5, gal);
        keep_box(build, hall, 3, self.wide - 5, 6, self.wide - 4, gal);
        build.teleporter(float(self.long) - 3.0, 3.0, gal, 3.0, float(cy) + 0.5, 0, 0.0);
        # The hurting pit behind the dais, a pad out of it.
        guards = build.waiting();
        build.widen(hall, cx + 8, cy - 3, -8, self.long - 4, cy + 3, 0);
        pit_fall(build, cx + 8, cy - 3, self.long - 4, cy + 3, -8, "The pit's floor burns", guards);
        pad_to(build, float(cx) + 9.5, float(cy), -8, float(cx) + 9.5, float(cy) + 5.5, 0);
        keep_box(build, hall, cx + 8, cy + 3, cx + 11, cy + 4, 0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # On the dais, the galleries' guards wake.
        top = wake_on(build, float(cx - 5), float(cy - 5), float(cx + 5), float(cy + 5), 6.0);
        build.foe(float(cx) + 5.5, 2.5, gal, demon_foe(dice, self.danger), 90.0, waits=top);
        build.foe(float(cx) - 5.5, float(self.wide) - 2.5, gal, demon_foe(dice, self.danger), 270.0, waits=top);
        build.foe(float(self.long) - 3.5, float(cy) + 6.5, 0, demon_foe(dice, self.danger), 180.0, waits=guards);
        build.foe(float(cx) + 2.5, float(cy) + 2.5, 6, demon_foe(dice, self.danger, True), 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx - 6 + index * 6) + 0.5, float(cy) + (8.5 if index % 2 == 0 else -8.5), 0, demon_foe(dice, self.danger), 0.0);
        }
        build.supply(float(cx) - 2.5, float(cy) + 0.5, 6, Q3_ARMOR, "q3");
        build.supply(3.0, 3.0, gal, Q3_HEALTH, "q3");
        build.supply(3.0, float(self.wide) - 6.5, 0, Q3_HEALTH, "q3");
    }
}

"""The key room: the key on an altar behind a hurting pit, over a pad or a
bridge swept by blades and a lift; taking it opens the closets."""
node DemonAltar(Prefab) {
    has key: str = "key_silver",
        padded: bool = True,
        hall_wide: int = 16,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Demon altar (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3DM15;
        self.district = level_district(Q3DM15);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.padded = dice.chance(0.5);
        self.tall = 18;
        self.low = -9;
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
        ax = self.long - 6;
        px = self.long - 12;
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, 8);
        build.doorway(room, self.enter);
        # The altar across the far end, the hurting pit before it, a pad
        # out of the pit.
        build.solid(ax, 1, 0, self.long - 1, side, 8);
        guards = build.waiting();
        build.widen(room, px, 1, -8, ax, side, 0);
        pit_fall(build, px, 1, ax, side, -8, "The pit's floor burns", guards);
        pad_to(build, float(px + 3), float(cy) - 2.5, -8, float(px) - 3.0, float(cy) - 2.5, 0);
        keep_box(build, room, px - 1, cy - 4, px, cy - 1, 0);
        if self.padded {
            pad_to(build, float(px - 3), float(cy) + 3.5, 0, float(self.long) - 3.0, float(cy) + 3.5, 8);
            keep_box(build, room, px - 1, cy + 2, px, cy + 5, 0);
            keep_box(build, room, ax, cy + 2, ax + 1, cy + 5, 8);
        } else {
            # A bridge over the pit swept by blades, a lift at its end up
            # onto the altar.
            deck(build, px, cy + 2, ax - 3, cy + 5, 0);
            keep_box(build, room, px - 1, cy + 2, px, cy + 5, 0);
            lift(build, ax - 3, cy + 2, ax, cy + 5, 0, 8);
            keep_box(build, room, ax, cy + 2, ax + 1, cy + 5, 8);
            blades(build, [px + 1, px + 3], float(side) - 0.2, 1.0, 3);
        }
        taken = key_taken(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, 8);
        closets(build, taken, side, 0, [1, 5], [demon_foe(dice, self.danger, True), demon_foe(dice, self.danger)]);
        taken +>:Fires:+> guards;
        build.foe(float(self.long) - 3.0, 2.5, 8, demon_foe(dice, self.danger), 180.0, waits=guards);
        build.foe(float(px) - 3.5, float(side) - 2.5, 0, demon_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(side) - 2.5, 8, Q3_HEALTH, "q3");
    }
}

"""An end (or a gate): a ledge along one wall, a balcony across the far
wall thrown up to from it, the way out on the balcony; a hurting pit."""
node DemonSanctum(Prefab) {
    has key: str = "",
        padded: bool = False,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Demon sanctum" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3DM15;
        self.district = level_district(Q3DM15);
        self.long = dice.between(28, 30);
        self.wide = dice.between(18, 20);
        self.padded = dice.chance(0.5);
        self.tall = dice.between(22, 23);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        wall = 8;
        bx = self.long - 6;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        build.level(room, 6);
        build.level(room, 12);
        # The ledge along the north wall, up a stair or a pad.
        deck(build, wall + 1, self.wide - 5, self.long - 1, self.wide - 1, 6);
        if self.padded {
            pad_to(build, float(wall + 5), float(self.wide - 8), 0, float(wall + 5), float(self.wide) - 3.0, 6);
            keep_box(build, room, wall + 4, self.wide - 5, wall + 7, self.wide - 4, 6);
        } else {
            stair(build, wall + 2, self.wide - 8, 0, 0, 6, 3);
            keep_box(build, room, wall + 6, self.wide - 5, wall + 9, self.wide - 4, 6);
        }
        # The balcony across the far wall over the floor and the ledge's end,
        # a pad on the ledge up to it; the way out on it.
        deck(build, bx, 1, self.long - 1, self.wide - 1, 12);
        pad_to(build, float(bx - 3), float(self.wide) - 3.0, 6, float(self.long) - 3.0, float(self.wide) - 3.0, 12);
        keep_box(build, room, bx, self.wide - 5, bx + 1, self.wide - 1, 12);
        build.way_out(float(self.long) - 3.0, float(mid) - 2.0, 12);
        # The hurting pit in the floor, a pad out of it.
        guards = build.waiting();
        build.widen(room, wall + 5, 4, -8, bx - 2, self.wide - 10, 0);
        pit_fall(build, wall + 5, 4, bx - 2, self.wide - 10, -8, "The pit's floor burns", guards);
        pad_to(build, float(wall + 8), float(mid) - 1.5, -8, float(wall + 2), float(mid) - 1.5, 0);
        keep_box(build, room, wall + 4, mid - 3, wall + 5, mid, 0);
        inside = build.touch(float(wall + 1), float(mid - 2), 0.0, float(wall + 3), float(mid + 2), 6.0);
        inside +>:Fires:+> guards;
        build.foe(float(self.long) - 3.0, 3.0, 12, demon_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(self.long) - 8.5, float(self.wide) - 3.0, 6, demon_foe(dice, self.danger), 180.0, waits=guards);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, demon_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(bx) - 1.5, 2.5, 0, "monster_knight", 180.0);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(self.wide) - 5.5, 12, Q3_HEALTH, "q3");
    }
}

"""q3dm15's stretches: [name, role]."""
glob Q3DM15_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["blades", "flow"],
         ["hall", "flow"],
         ["throne", "hub"],
         ["altar", "keyroom"],
         ["sanctum", "end"],
         ["sanctum", "gate"]
     ];

"""One of q3dm15's stretches by its name."""
def make_q3dm15(name: str, key: str) -> Prefab {
    if name == "gate" {
        return DemonGate();
    }
    if name == "blades" {
        return DemonBladePit();
    }
    if name == "hall" {
        return DemonHall();
    }
    if name == "throne" {
        return DemonThrone();
    }
    if name == "altar" {
        return DemonAltar(key=key if key else "key_silver");
    }
    return DemonSanctum(key=key);
}
