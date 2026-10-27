"""Prefabs drawn from Quake II's city1, the Outer Courts of the Strogg city:
courts under the sky between arcades whose roofs are terraces, the wind
shafts whose updrafts carry a body up the towers, canals under arched
bridges, the court where the hovers come in wave after wave, rooftops
crossed by bridges and updrafts, the vault of the data spinner, and the
gate of the leader's palace. Raised in city1's own palette.

- `OuterCourts`: the start. A court, an arcade along one side whose roof
  is a terrace up a stair (or an updraft), a walkway along the other; a
  heap of debris in a gateway that bursts when shot (a secret); the
  hovers come in after the player; "Neutralize the Strogg leader's
  command center".
- `WindShaft`: a tower shaft, an updraft from its floor to a ledge and
  another from the ledge across to the gallery at the top (or a lift to
  the ledge).
- `CanalQuarter`: a canal down the quarter's middle, quays along it,
  arched bridges over it up steps (the far one drawn out by a button), balconies over the quays on arcades;
  guards come onto the balconies as the player crosses.
- `HoverCourt`: a plaza round a fountain, terraces along two sides over
  arcades (a catwalk across the plaza from one) and a higher one over
  them up an updraft, a teleporter to the
  high terrace; the hovers come in three waves. A hub.
- `Rooftops`: the street under three roofs at rising heights, steps to
  the first raised by a button on the wall, steps on to the second, an
  updraft to the third and a bridge from it back over the street.
- `DataVault`: the data spinner (the key) on a pedestal up a lift in a
  vault under its gallery; taking it opens the closets.
- `PalaceGate`: the end. A door (a key's, as a gate) out to the palace's
  forecourt, a grand stair between pylons up to the terrace and the way
  out at the palace door; the guards come down, charges go off."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, gate_into, lift, pillars }
import from .q2_works { deck, keep_box, sparking, blast_chain, stash, hidden_closet, squad, rounds, beamed, held_door, key_taken, closets, pad_to, splashing, barrels }

glob CITY1: str = "q2:city1";

"""city1's foes: elite guards and gladiators, hovers in the air, a tank
commander deeper in."""
def city1_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_soldier_ss", "monster_gladiator"] if heavy else ["monster_soldier_ss", "monster_soldier_ss", "monster_hover"], ["monster_tank_commander"] if heavy else ["monster_gladiator"], danger * 0.3 if heavy else danger * 0.5));
}

"""Hovers coming in wave after wave once `cue` fires: each wave `gap`
seconds after the last, its hovers at `spots` ([x, y, z] each, in turn)."""
def hover_waves(build: Raising, cue: Cue, waves: int, gap: float, spots: list[list[float]]) {
    last = cue;
    for wave in range(waves) {
        late = build.delay(gap);
        last +>:Fires:+> late;
        squad(build, late, [spots[(wave * 2) % len(spots)]], ["monster_hover"], 180.0);
        after = build.delay(0.75);
        late +>:Fires:+> after;
        squad(build, after, [spots[(wave * 2 + 1) % len(spots)]], ["monster_hover"], 180.0);
        after +>:Fires:+> build.sparks(spots[(wave * 2 + 1) % len(spots)][0], spots[(wave * 2 + 1) % len(spots)][1], spots[(wave * 2 + 1) % len(spots)][2], 0);
        last = late;
    }
}

"""The start: a court, an arcade whose roof is a terrace, a walkway along
the other side, debris in a gateway."""
node OuterCourts(Prefab) {
    has roof: int = 12,
        walk: int = 8,
        updraft: bool = False,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Outer courts";
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(30, 32);
        self.wide = dice.between(24, 26);
        self.roof = 12;
        self.walk = 8;
        self.tall = 22;
        self.updraft = dice.chance(0.45);
        self.low = -9;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle + 1), floor=0),
            Port(face=0, along=4.0, floor=self.roof),
            Port(face=1, along=float(self.long - 8), floor=self.walk)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        r = self.roof;
        w = self.walk;
        court = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(court, r);
        build.level(court, w);
        # The arcade along the near side, its roof a terrace; pillars along
        # its front.
        build.solid(6, 1, 6, self.long - 1, 7, r);
        for x in range(8, self.long - 2, 4) {
            build.solid(x, 6, 0, x + 1, 7, 6);
        }
        if self.updraft {
            pad_to(build, float(self.long) - 9.5, 10.0, 0, float(self.long) - 9.5, 4.0, r);
            keep_box(build, court, self.long - 12, 6, self.long - 7, 7, r);
        } else {
            stair(build, 6, 7, 0, 0, r, 3);
            keep_box(build, court, 6 + r - 1, 6, 6 + r + 1, 7, r);
        }
        # A bridge from the arcade's roof out over the court to look down on
        # the walkway.
        bx = self.long - 6;
        deck(build, bx, 7, bx + 3, self.wide - 4, r);
        keep_box(build, court, bx, 6, bx + 3, 7, r);
        # The walkway along the far side over the court, up a stair.
        deck(build, 10, self.wide - 4, self.long - 1, self.wide - 1, w);
        stair(build, 2, self.wide - 4, 0, 0, w, 3);
        keep_box(build, court, 10, self.wide - 4, 11, self.wide - 1, w);
        # Debris in a gateway in the far wall, bursting when shot on a stash.
        gx = self.long // 2 - 2;
        build.solid(gx - 1, self.wide - 8, 0, gx + 5, self.wide - 4, 6);
        nook = build.room(gx, self.wide - 7, 0, gx + 4, self.wide - 5, 4);
        build.widen(nook, gx, self.wide - 8, 0, gx + 4, self.wide - 7, 4);
        debris = build.breakable(float(gx), float(self.wide - 8), 0.0, float(gx + 4), float(self.wide - 7), 4.0, 30);
        build.secret(float(gx), float(self.wide - 7), 0.0, float(gx + 4), float(self.wide - 5), 3.0);
        build.supply(float(gx) + 2.0, float(self.wide) - 6.0, 0, Q2_ARMOR, "q2");
        debris +>:Fires:+> build.explosion(float(gx) + 2.0, float(self.wide) - 9.0, 1.0);
        build.touch(float(gx), float(self.wide - 11), 0.0, float(gx + 4), float(self.wide - 9), 6.0, True, "The gate is blocked by debris");
        build.doorway(court, self.enter);
        for port in self.taken {
            build.doorway(court, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 7.0, 0.0, 4.0, float(self.wide - 4), 8.0) +>:Fires:+> build.objective("Neutralize the Strogg leader's command center");
        # The hovers come in after the player; guards on the terrace and the
        # walkway, one walking the arcade.
        come_in = build.touch(5.0, 7.0, 0.0, 7.0, float(self.wide - 8), 8.0);
        hover_waves(build, come_in, 2, 4.0, [[float(self.long // 2), float(middle), 14.0], [float(self.long) - 6.0, float(middle) + 3.0, 15.0], [8.0, float(middle) - 2.0, 13.0], [float(self.long) - 10.0, float(middle), 16.0]]);
        build.foe(float(self.long) - 4.5, 3.5, r, city1_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long) - 4.5, float(self.wide) - 2.5, w, city1_foe(dice, self.danger), 180.0);
        rounds(build, "monster_soldier_ss", [[8.5, 3.5], [float(self.long) - 3.5, 3.5]], 0);
        build.foe(float(self.long) - 6.5, float(middle) + 1.5, 0, city1_foe(dice, self.danger), 180.0);
        sparking(build, float(self.long) - 1.2, float(middle) - 2.0, 3.0, 2, 5.0);
        sparking(build, 6.2, 4.0, float(r) - 3.0, 0, 7.0);
        sparking(build, float(self.long) - 1.2, float(self.wide) - 2.5, float(w) + 2.0, 2, 6.5);
        barrels(build, dice, 8, 8, self.long - 4, self.wide - 9, 0, 2, [[0, middle - 3, 6, middle + 4], [5, 7, 19, 11], [self.long - 13, 7, self.long - 6, 12], [gx - 1, self.wide - 12, gx + 5, self.wide], [self.long - 4, middle - 2, self.long, middle + 4]]);
        build.supply(float(self.long) - 3.5, float(middle) + 3.5, 0, Q2_HEALTH, "q2");
        build.supply(10.5, 3.5, r, "ammo_bullets", "q2");
    }
}

"""A tower shaft, an updraft to a ledge and another across to the gallery
at the top."""
node WindShaft(Prefab) {
    has ledge: int = 9,
        top: int = 18,
        by_lift: bool = False,
        tall: int = 29;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Wind shaft";
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(20, 22);
        self.wide = dice.between(18, 20);
        self.ledge = 9;
        self.top = dice.between(17, 19);
        self.tall = self.top + 11;
        self.by_lift = dice.chance(0.35);
        self.low = -9;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy), floor=0);
        self.leaves = [
            Port(face=0, along=float(cy - 5), floor=0),
            Port(face=1, along=4.0, floor=self.top),
            Port(face=3, along=4.0, floor=self.top)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        l = self.ledge;
        t = self.top;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, l);
        build.level(shaft, t);
        # The ledge along the far wall, the gallery along the near one at the
        # top.
        lx = self.long - 6;
        deck(build, lx, 1, self.long - 1, self.wide - 1, l);
        deck(build, 1, 1, 7, self.wide - 1, t);
        deck(build, 7, 1, lx, 5, l);
        keep_box(build, shaft, lx - 1, 1, lx, 5, l);
        keep_box(build, shaft, lx, cy - 2, lx + 1, cy + 2, l);
        keep_box(build, shaft, 6, cy - 2, 7, cy + 2, t);
        # Up to the ledge: an updraft from the floor, or a lift.
        if self.by_lift {
            lift(build, lx - 3, cy - 1, lx, cy + 2, 0, l);
        } else {
            pad_to(build, float(lx) - 3.0, float(cy), 0, float(lx) + 2.0, float(cy), l);
            build.touch(float(lx - 6), float(cy - 2), 0.0, float(lx - 4), float(cy + 2), 6.0, True, "The updraft carries you up");
        }
        # From the ledge, an updraft back across the shaft to the gallery.
        pad_to(build, float(lx) + 3.0, float(cy), l, 4.0, float(cy), t);
        vents = build.push(1.0, float(cy) + 0.5, float(t) + 1.5, 0);
        vents +>:Fires:+> build.objective("Vents opened", False);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
            if port.floor == t {
                held_door(build, self, port, vents, "The vents are opened from the gallery's wall");
            }
        }
        # Hovers in the shaft, guards waiting at the top as the player lands.
        landed = build.touch(1.0, float(cy - 3), float(t), 7.0, float(cy + 3), float(t + 6));
        squad(build, landed, [[3.5, 3.0, float(t)], [3.5, float(self.wide) - 3.0, float(t)]], [city1_foe(dice, self.danger, True), "monster_soldier_ss"], 0.0);
        on_ledge = build.touch(float(lx), float(cy - 3), float(l), float(self.long - 1), float(cy + 3), float(l + 6));
        hover_waves(build, on_ledge, 1, 2.0, [[10.0, 4.0, float(t - 2)], [10.0, float(self.wide) - 4.0, float(t - 2)]]);
        beamed(build, on_ledge, 2, 2, -8, city1_foe(dice, self.danger), float(lx) + 2.5, 3.5, l, 180.0);
        build.foe(float(self.long // 2), float(cy) + 4.5, 6, "monster_hover", 0.0);
        rounds(build, "monster_soldier_ss", [[float(lx) + 2.5, 3.0], [float(lx) + 2.5, float(self.wide) - 3.0]], l);
        build.foe(4.5, float(cy) + 4.5, 0, city1_foe(dice, self.danger), 0.0);
        sparking(build, float(self.long) - 1.2, float(cy) + 3.0, float(l) + 2.0, 2, 4.0);
        build.supply(3.0, 3.0, 0, Q2_HEALTH, "q2");
        build.supply(3.0, float(self.wide) - 3.0, t, "ammo_bullets", "q2");
        sparking(build, 1.2, float(cy) - 3.0, float(t) + 3.0, 0, 6.0);
    }
}

"""A canal down the quarter's middle, quays along it, arched bridges over
it, balconies over the quays on arcades."""
node CanalQuarter(Prefab) {
    has bal: int = 8,
        bridges: list[int] = [],
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Canal quarter";
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(30, 32);
        self.wide = dice.between(24, 26);
        self.bal = 8;
        self.tall = 18;
        self.bridges = [dice.between(10, 14)];
        if dice.chance(0.6) {
            self.bridges.append(dice.between(18, self.long - 12));
        }
        self.low = -9;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy - 6), floor=0);
        self.leaves = [
            Port(face=0, along=float(cy - 6), floor=0),
            Port(face=0, along=float(cy + 6), floor=0),
            Port(face=1, along=float(self.long // 2), floor=self.bal),
            Port(face=3, along=float(self.long - 6), floor=self.bal)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        b = self.bal;
        quarter = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(quarter, b);
        # The canal, a stair up out of it onto each quay.
        build.pool(1, cy - 3, -6, self.long - 1, cy + 3, 0, 2, steps=False);
        stair(build, 3, cy - 3, -6, 0, 6, 2);
        stair(build, self.long - 9, cy + 1, -6, 0, 6, 2);
        # The arched bridges over it, steps up from each quay.
        for (index, bx) in enumerate(self.bridges) {
            stair(build, bx, cy - 6, 0, 1, 3, 3);
            stair(build, bx, cy + 5, 0, 3, 3, 3);
            if index == 0 {
                deck(build, bx, cy - 3, bx + 3, cy + 3, 3);
            } else {
                # The far bridge drawn out over the canal by the button on its
                # landing.
                drawn = build.drawn(float(bx), float(cy - 3), float(bx + 3), float(cy + 3), 3, 4);
                build.push(float(bx + 3), float(cy) - 4.5, 1.5, 0) +>:Fires:+> drawn;
                keep_box(build, quarter, bx, cy - 4, bx + 3, cy - 3, 3);
                keep_box(build, quarter, bx, cy + 3, bx + 3, cy + 4, 3);
            }
        }
        # The balconies over both quays on their arcades, a stair up to each.
        deck(build, 9, 1, self.long - 1, 5, b);
        deck(build, 9, self.wide - 5, self.long - 1, self.wide - 1, b);
        for x in range(10, self.long - 2, 5) {
            build.solid(x, 4, 0, x + 1, 5, b - 1);
            build.solid(x, self.wide - 5, 0, x + 1, self.wide - 4, b - 1);
        }
        stair(build, 1, 1, 0, 0, b, 3);
        stair(build, 1, self.wide - 4, 0, 0, b, 3);
        keep_box(build, quarter, 9, 1, 10, 4, b);
        keep_box(build, quarter, 9, self.wide - 4, 10, self.wide - 1, b);
        build.doorway(quarter, self.enter);
        for port in self.taken {
            build.doorway(quarter, port);
        }
        # Guards come onto the balconies as the player starts over a bridge;
        # hovers over the canal; one walking the quay.
        first = self.bridges[0];
        over = build.touch(float(first), float(cy - 3), 3.0, float(first + 3), float(cy + 3), 9.0);
        squad(build, over, [[float(self.long) - 4.5, 2.5, float(b)], [float(self.long) - 8.5, float(self.wide) - 2.5, float(b)], [16.5, float(self.wide) - 2.5, float(b)]], [city1_foe(dice, self.danger, True), "monster_soldier_ss", city1_foe(dice, self.danger)], 180.0);
        hover_waves(build, over, 1, 3.0, [[float(self.long // 2), float(cy), 8.0], [float(self.long) - 6.0, float(cy), 9.0]]);
        rounds(build, "monster_soldier_ss", [[3.5, float(cy) - 5.0], [float(self.long) - 3.5, float(cy) - 5.0]], 0);
        build.foe(float(self.long) - 5.5, float(cy) + 5.0, 0, city1_foe(dice, self.danger), 180.0);
        build.foe(12.5, float(cy) + 0.5, -4, "monster_flipper", 0.0);
        splashing(build, 14.5, float(cy), -1.0, 5.0);
        sparking(build, 1.2, float(cy) + 5.0, 3.0, 0, 4.0);
        sparking(build, float(self.long) - 1.2, 3.0, float(b) + 2.0, 2, 5.5);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 2.5, b, "ammo_grenades", "q2");
    }
}

"""A plaza round a fountain, terraces along two sides over arcades and a
higher one over them; the hovers come in three waves."""
node HoverCourt(Prefab) {
    has terrace: int = 6,
        upper: int = 13,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hover court";
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(30, 32);
        self.wide = dice.between(28, 30);
        self.terrace = 9;
        self.upper = 16;
        self.tall = 26;
        self.low = -9;
        self.high = self.tall + 1;
        middle = self.wide // 2;
        self.enter = Port(face=2, along=float(middle + 2), floor=0);
        self.leaves = [
            Port(face=0, along=float(middle), floor=0),
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=0, along=float(self.wide - 4), floor=self.terrace),
            Port(face=3, along=float(self.long // 2 - 3), floor=self.upper)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        te = self.terrace;
        up = self.upper;
        plaza = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(plaza, te);
        build.level(plaza, up);
        # The fountain in the plaza's middle, its basin and its column.
        build.pool(cx - 4, cy - 2, -4, cx + 3, cy + 5, 0, 2, steps=False);
        stair(build, cx - 4, cy - 2, -4, 0, 4, 2);
        build.solid(cx, cy + 1, -4, cx + 2, cy + 3, 6);
        # The terraces along the near side and the far end over arcades, the
        # stair up to them; the high terrace over the near one.
        deck(build, 1, 1, self.long - 1, 7, te);
        deck(build, self.long - 7, 7, self.long - 1, self.wide - 1, te);
        for x in range(4, self.long - 7, 5) {
            build.solid(x, 6, 0, x + 1, 7, te - 1);
        }
        stair(build, 8, 7, 0, 0, te, 3);
        keep_box(build, plaza, 8 + te - 1, 6, 8 + te + 1, 7, te);
        deck(build, 1, 1, self.long - 8, 5, up);
        px = self.long - 12;
        pad_to(build, float(px), 10.0, 0, float(px), 3.0, up);
        keep_box(build, plaza, px - 2, 6, px + 2, 7, te);
        keep_box(build, plaza, px - 2, 4, px + 2, 5, up);
        # A catwalk from the near terrace across the plaza to the far wall.
        deck(build, 4, 7, 7, self.wide - 1, te);
        keep_box(build, plaza, 4, 6, 7, 7, te);
        sparking(build, 4.5, float(self.wide) - 1.2, float(te) + 2.0, 3, 6.0);
        # A teleporter in the far corner to the high terrace.
        build.teleporter(4.0, float(self.wide) - 4.0, 0, 3.0, 3.0, up, 0.0);
        build.doorway(plaza, self.enter);
        for port in self.taken {
            build.doorway(plaza, port);
        }
        # The hovers come in three waves once the player is in the plaza.
        come_in = build.touch(1.0, float(cy - 1), 0.0, 4.0, float(cy + 5), 8.0);
        hover_waves(build, come_in, 3, 5.0, [[float(cx), float(cy) - 4.0, 12.0], [float(cx) + 6.0, float(cy) + 6.0, 14.0], [float(cx) - 8.0, float(cy) + 6.0, 13.0], [float(cx) + 2.0, float(cy) + 9.0, 15.0], [8.0, float(cy) + 2.0, 12.0], [float(self.long) - 12.0, float(cy), 16.0]]);
        squad(build, come_in, [[float(self.long) - 4.0, float(cy) + 3.0, float(te)], [float(cx) + 3.0, 3.0, float(up)]], [city1_foe(dice, self.danger, True), "monster_soldier_ss"], 180.0);
        hidden_closet(build, self.long - 13, self.wide - 6, 0, 3, Q2_ARMOR, 6) +>:Fires:+> build.sparks(float(self.long) - 11.0, float(self.wide) - 6.2, 3.0, 3);
        rounds(build, "monster_soldier_ss", [[3.0, 3.5], [float(self.long) - 3.0, 3.5], [float(self.long) - 3.0, float(self.wide) - 3.0]], te);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) + 5.5, float(cy) - 3.5 + float(index) * 7.0, 0, city1_foe(dice, self.danger), 180.0);
        }
        splashing(build, float(cx) - 1.0, float(cy) + 1.0, -1.0, 3.0);
        sparking(build, float(self.long) - 1.2, float(cy) - 4.0, float(te) + 2.0, 2, 5.0);
        build.supply(2.5, float(cy) + 0.5, 0, Q2_HEALTH, "q2");
        build.supply(float(cx) + 4.5, 3.0, up, "ammo_rockets", "q2");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, te, Q2_HEALTH, "q2");
    }
}

"""The street under three roofs at rising heights: a stair to the first, a
bridge to the second, an updraft to the third."""
node Rooftops(Prefab) {
    has roof_a: int = 4,
        roof_b: int = 8,
        roof_c: int = 13,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rooftops";
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(30, 32);
        self.wide = dice.between(22, 24);
        self.roof_a = dice.between(4, 5);
        self.roof_b = self.roof_a + 4;
        self.roof_c = self.roof_b + 5;
        self.tall = self.roof_c + 11;
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide // 2), floor=0),
            Port(face=0, along=4.0, floor=self.roof_c),
            Port(face=1, along=float(self.long - 5), floor=self.roof_c)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        a = self.roof_a;
        b = self.roof_b;
        c = self.roof_c;
        street = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(street, a);
        build.level(street, b);
        build.level(street, c);
        # Three buildings along the near side, their roofs rising; the street
        # along the far side under them.
        build.solid(4, 1, 0, 12, 8, a);
        build.solid(15, 1, 0, 22, 8, b);
        build.solid(self.long - 8, 1, 7, self.long - 1, 9, c);
        build.solid(self.long - 2, 1, 0, self.long - 1, 9, 7);
        for x in range(self.long - 8, self.long - 2, 3) {
            build.solid(x, 8, 0, x + 1, 9, 7);
        }
        # A stair from the street up to the first roof, a bridge from it up
        # steps to the second, over the street.
        steps = build.rising_steps(4, 7 + a, 0, 3, a, 3);
        build.push(1.0, float(8 + a) + 1.5, 1.5, 0) +>:Fires:+> steps;
        build.touch(1.0, float(8 + a - 2), 0.0, 3.0, float(8 + a + 2), 6.0, True, "The steps to the roofs are raised from the wall");
        keep_box(build, street, 4, 7, 7, 8, a);
        build.solid(12, 1, 0, 15, 8, a);
        stair(build, 12, 3, a, 0, b - a, 3);
        keep_box(build, street, 15, 3, 16, 6, b);
        # From the second roof an updraft to the third.
        pad_to(build, 18.5, 4.5, b, float(self.long) - 4.5, 4.5, c);
        keep_box(build, street, 21, 2, 22, 7, b);
        keep_box(build, street, self.long - 8, 2, self.long - 7, 7, c);
        # A high bridge from the third roof back over the street to a ledge.
        deck(build, self.long - 7, 9, self.long - 3, self.wide - 1, c);
        keep_box(build, street, self.long - 7, 8, self.long - 3, 9, c);
        build.doorway(street, self.enter);
        for port in self.taken {
            build.doorway(street, port);
        }
        # Guards on the roofs wake as the player comes up; hovers come in
        # over the street.
        up = build.touch(4.0, 4.0, float(a), 7.0, 8.0, float(a + 6));
        squad(build, up, [[18.5, 6.0, float(b)], [float(self.long) - 4.5, 6.0, float(c)]], [city1_foe(dice, self.danger, True), "monster_soldier_ss"], 180.0);
        hover_waves(build, up, 1, 3.0, [[14.0, float(cy) + 4.0, 12.0], [float(self.long) - 10.0, float(cy) + 3.0, 14.0]]);
        rounds(build, "monster_soldier_ss", [[3.5, float(self.wide) - 3.0], [float(self.long) - 14.5, float(self.wide) - 3.0]], 0);
        build.foe(8.5, 4.5, a, city1_foe(dice, self.danger), 0.0);
        beamed(build, up, 2, self.wide - 6, -8, city1_foe(dice, self.danger), 20.5, float(cy) + 4.5, 0, 180.0);
        stash(build, 24, self.wide - 6, 0, 3, Q2_ARMOR, 6) +>:Fires:+> build.explosion(26.0, float(self.wide) - 7.0, 1.0);
        barrels(build, dice, 2, 10, self.long - 9, self.wide - 7, 0, 2, [[0, cy - 3, 4, cy + 3], [3, 8, 8, 9 + a], [0, self.wide - 4, self.long, self.wide], [22, self.wide - 7, 29, self.wide]]);
        sparking(build, float(self.long - 8) - 0.2, 5.0, float(c) - 3.0, 2, 5.0);
        sparking(build, 1.2, float(self.wide) - 4.0, 4.0, 0, 6.0);
        sparking(build, 12.2, 2.0, float(a) + 2.0, 0, 4.0);
        build.supply(2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.5, 3.0, c, "ammo_cells", "q2");
    }
}

"""The data spinner on a pedestal up a lift in a vault under its gallery;
taking it opens the closets."""
node DataVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        gal: int = 7,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Data vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.gal = 7;
        self.tall = 16;
        self.low = -9;
        self.high = 18;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        g = self.gal;
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, g);
        build.doorway(vault, self.enter);
        # The gallery along the near wall and the far end, up a stair; the
        # pedestal in the middle at the gallery's height, a lift up to it.
        deck(build, 8, 1, self.long - 1, 5, g);
        deck(build, self.long - 5, 5, self.long - 1, side, g);
        stair(build, 1, 1, 0, 0, g, 3);
        keep_box(build, vault, 8, 1, 9, 4, g);
        px = self.long // 2;
        build.solid(px - 2, cy - 1, 0, px + 2, cy + 3, g);
        lift(build, px - 5, cy, px - 2, cy + 3, 0, g);
        keep_box(build, vault, px - 2, cy, px - 1, cy + 3, g);
        taken = key_taken(build, self.key, float(px), float(cy) + 1.0, g);
        taken +>:Fires:+> build.objective("Data spinner taken. Make for the palace gate", False);
        closets(build, taken, side, 0, [3, self.long - 8], [city1_foe(dice, self.danger, True), city1_foe(dice, self.danger)]);
        squad(build, taken, [[float(self.long) - 3.0, float(side) - 3.0, float(g)], [12.5, 3.0, float(g)]], ["monster_hover", city1_foe(dice, self.danger)], 180.0);
        beamed(build, taken, 2, 2, -8, city1_foe(dice, self.danger, True), 5.5, float(cy) + 0.5, 0, 0.0);
        rounds(build, "monster_soldier_ss", [[10.5, 3.0], [float(self.long) - 3.0, 3.0], [float(self.long) - 3.0, float(side) - 3.0]], g);
        build.foe(float(px) + 4.5, float(cy) + 0.5, 0, city1_foe(dice, self.danger), 180.0);
        sparking(build, float(self.long) - 1.2, float(cy) + 2.0, float(g) + 2.0, 2, 3.0);
        sparking(build, float(px) - 2.2, float(cy) - 0.5, 3.0, 2, 5.0);
        sparking(build, 1.2, float(cy) + 3.0, 3.0, 0, 7.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door out to the palace's forecourt, a grand stair between
pylons up to the terrace, the way out at the palace door."""
node PalaceGate(Prefab) {
    has key: str = "",
        terrace: int = 8,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Palace gate" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = CITY1;
        self.district = level_district(CITY1);
        self.long = dice.between(30, 32);
        self.wide = dice.between(20, 22);
        self.terrace = 8;
        self.tall = 22;
        self.low = -1;
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
        te = self.terrace;
        court = gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key, True);
        build.level(court, te);
        # The terrace at the far end before the palace door, the grand stair
        # up to it between pylons.
        tx = self.long - 8;
        build.solid(tx, 1, 0, self.long - 1, self.wide - 1, te);
        stair(build, tx - te, middle - 3, 0, 0, te, 6);
        keep_box(build, court, tx, middle - 3, tx + 1, middle + 3, te);
        deck(build, wall + 8, 1, tx, 4, 6);
        deck(build, wall + 8, self.wide - 4, tx, self.wide - 1, 6);
        stair(build, wall + 2, 1, 0, 0, 6, 3);
        stair(build, wall + 2, self.wide - 4, 0, 0, 6, 3);
        keep_box(build, court, wall + 8, 1, wall + 9, 4, 6);
        keep_box(build, court, wall + 8, self.wide - 4, wall + 9, self.wide - 1, 6);
        build.foe(float(tx) - 3.0, 2.5, 6, "monster_soldier_ss", 180.0);
        build.foe(float(tx) - 3.0, float(self.wide) - 2.5, 6, city1_foe(dice, self.danger), 180.0);
        for py in [middle - 6, middle + 4] {
            build.solid(tx + 1, py, te, tx + 3, py + 2, te + 6);
        }
        build.solid(self.long - 2, middle - 3, te, self.long - 1, middle + 3, te + 8);
        build.way_out(float(self.long) - 4.0, float(middle), te);
        # The guards come down from the terrace as the player comes out; the
        # charges go off on the stair.
        out = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        squad(build, out, [[float(tx) + 3.0, 3.0, float(te)], [float(tx) + 3.0, float(self.wide) - 3.0, float(te)]], [city1_foe(dice, self.danger, True), "monster_gladiator"], 180.0);
        hover_waves(build, out, 1, 4.0, [[float(tx) - 6.0, float(middle), 14.0], [float(tx) + 2.0, float(middle) + 4.0, 16.0]]);
        climb = build.touch(float(tx - te), float(middle - 3), 1.0, float(tx - te + 3), float(middle + 3), 7.0);
        blast_chain(build, climb, [[float(tx) - 5.0, float(middle) - 5.0, 3.0], [float(tx) - 5.0, float(middle) + 5.0, 3.0], [float(tx) + 2.0, float(middle), float(te) + 2.0]], 0.4);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, city1_foe(dice, self.danger, index == 0), 180.0);
        }
        rounds(build, "monster_soldier_ss", [[float(wall) + 3.5, 3.0], [float(tx) - 2.5, 3.0]], 0);
        sparking(build, float(tx) - 0.2, 3.5, 3.0, 2, 4.0);
        sparking(build, float(tx) - 0.2, float(self.wide) - 3.5, 3.0, 2, 5.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 3.0, float(middle) + 0.5, 0, "ammo_rockets", "q2");
    }
}

"""city1's stretches: [name, role]."""
glob CITY1_STRETCHES: list[list[str]] = [
         ["courts", "start"],
         ["wind", "flow"],
         ["canal", "flow"],
         ["roofs", "flow"],
         ["hovers", "hub"],
         ["canal", "hub"],
         ["vault", "keyroom"],
         ["palace", "end"],
         ["palace", "gate"]
     ];

"""One of city1's stretches by its name."""
def make_city1(name: str, key: str) -> Prefab {
    if name == "courts" {
        return OuterCourts();
    }
    if name == "wind" {
        return WindShaft();
    }
    if name == "canal" {
        return CanalQuarter();
    }
    if name == "roofs" {
        return Rooftops();
    }
    if name == "hovers" {
        return HoverCourt();
    }
    if name == "vault" {
        return DataVault(key=key if key else "key_silver");
    }
    return PalaceGate(key=key);
}
