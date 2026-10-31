"""Prefabs drawn from Quake III's q3tourney6, The Very End of You: Xaero's
arena, platforms floating in the void at many heights, its floors laid
with trapdoors that slide open when a button is shot (the foes on them
falling to the void), platforms bobbing and shuttling between islands,
a launch high up to the BFG's platform, low terraces thrown up from by
jump pads. Quake III's arenas hold no foes of their own; q3tourney6's
are hell_knight, shalrath, shambler. Raised in q3tourney6's own palette.
The void's floor burns whoever falls, and jump pads at its foot throw
them back up (as the original's do).

- `EndPlatform`: the start. A platform over the void, a stair down its
  side to a terrace, a pad from the terrace up to the far deck, and a long
  pad from the far deck back over the void.
- `TrapdoorBridge`: a wide bridge over the void whose middle is laid with
  trapdoors; shooting the button on the far pillar slides them open,
  dropping whoever stands on them; by the seed a ledge over the far deck
  thrown up to from the bridge.
- `LaunchSpire`: a deck over the void, the BFG's platform high over its
  far end thrown up to by a pad (or by way of a perch), a teleporter back
  down.
- `VoidCross`: the hub. A cross of decks over the void, a dais at the
  crossing, terraces low in one or two of the quarters between the arms
  (pads up from them, drops down to them), trapdoors along one arm opened
  by a button shot on the dais.
- `XaeroAltar`: the key room. A pad down from the entry ledge to an
  island, a platform bobbing up from it to the altar, the key there;
  taking it opens closets on the ledge, a teleporter back.
- `VeryEnd`: the end (or a gate, the door a key's). A hall, a deck over
  the void, a pad over to the last platform, and the way out in an alcove
  behind a door that opens when the button beside it is shot."""
import from ..random { Stream }
import from .roster { FoeMix }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .common { stair, key_ambush }
import from .q3arena { Q3_HEALTH, Q3_ARMOR }
import from .q3late_parts { deck, keep_box, void_floor, void_pads, throw, wake_later, columns }

glob Q3TOURNEY6: str = "q3:q3tourney6",
     Q3TOURNEY6_LIGHT: list[str] = ["monster_hell_knight", "monster_shalrath"],
     Q3TOURNEY6_HEAVY: list[str] = ["monster_shambler"];

"""A foe for q3tourney6's stretches."""
glob END_FOES: FoeMix = FoeMix(light=Q3TOURNEY6_LIGHT, strong=Q3TOURNEY6_HEAVY, heavy_light=Q3TOURNEY6_HEAVY, scale=0.5);

"""Trapdoors laid along the cells x0..x1, y0..y1 of a floor at lift `z`:
panels four cells long, each sliding aside (alternately +y and -y) into
the floor beside it when the cue they answer fires, back five seconds
on (the original's doors under the button). Answers their cue."""
def trapdoors(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int) -> Cue {
    items: list[dict[str, str]] = [];
    index = 0;
    for x in range(x0, x1, 4) {
        fields = {"classname": "func_door", "angle": str(build.facing(1 if index % 2 == 0 else 3)), "speed": "300", "wait": "5", "lip": "0"};
        build.put_box(fields, float(x), float(y0), float(z - 1), float(min(x + 4, x1)), float(y1), float(z), kit_of(build.district).step);
        build.casting.doors += 1;
        items.append(fields);
        index += 1;
    }
    return build.cue(items, "trapdoor");
}

"""The start: a platform over the void, a terrace down its side, a pad up
to the far deck and a long pad back."""
node EndPlatform(Prefab) {
    has terrace_side: int = 0,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "End platform";
        self.source = Q3TOURNEY6;
        self.district = level_district(Q3TOURNEY6);
        self.long = dice.between(30, 32);
        self.wide = dice.between(20, 22);
        self.terrace_side = dice.below(2);
        self.tall = 14;
        self.low = -19;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        ty = 2 if self.terrace_side == 0 else self.wide - 10;
        oy = (ty + 8 + self.wide - 1) // 2 if self.terrace_side == 0 else (1 + ty) // 2;
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=float(ty) + 4.0, floor=0), Port(face=1, along=float(self.long - 3), floor=0), Port(face=3, along=float(self.long - 3), floor=0), Port(face=0, along=float(oy) + 0.5, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -18;
        ty = 2 if self.terrace_side == 0 else self.wide - 10;
        oy = (ty + 8 + self.wide - 1) // 2 if self.terrace_side == 0 else (1 + ty) // 2;
        void = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, 0);
        build.level(void, -4);
        deck(build, 1, 1, 12, self.wide - 1, 0, 3);
        deck(build, 12, ty, 20, ty + 8, -4, 2);
        stair(build, 15, ty + 2, -4, 2, 4, 3);
        far = self.long - 7;
        deck(build, far, 1, self.long - 1, self.wide - 1, 0, 3);
        throw(build, void, 17.5, float(ty) + 4.0, -4, float(self.long) - 3.5, float(ty) + 4.0, 0, [19, ty + 2, 20, ty + 6], [far, ty + 2, far + 1, ty + 6]);
        throw(build, void, float(self.long) - 3.0, float(oy) + 0.5, 0, 8.0, float(oy) + 0.5, 0, [far, oy - 1, far + 1, oy + 2], [11, oy - 1, 12, oy + 2]);
        # The long pad from the platform straight over the void to the far
        # deck, beside the one back.
        out_y = oy + 3 if self.terrace_side == 0 else oy - 3;
        throw(build, void, 8.0, float(out_y) + 0.5, 0, float(self.long) - 3.5, float(out_y) + 0.5, 0, [11, out_y - 1, 12, out_y + 2], [far, out_y - 1, far + 1, out_y + 2]);
        void_pads(build, void, 1, 1, self.long - 1, self.wide - 1, low, [[18.0, float(oy) + 0.5, 5.0, float(oy) + 0.5, 0.0]], [[11, oy - 1, 12, oy + 2, 0]]);
        build.doorway(void, self.enter);
        for port in self.taken {
            build.doorway(void, port);
        }
        build.start(2.5, py, 0, 0.0);
        build.supply(2.5, py - 2.0, 0, "ammo_shells", "q2");
        build.supply(14.0, float(ty) + 6.5, -4, "weapon_rocketlauncher", "q3");
        build.supply(float(self.long) - 3.0, float(ty) + 1.5, 0, Q3_HEALTH, "q3");
        build.timer(5.0) +>:Fires:+> build.sparks(11.8, float(oy) + 3.0, 1.0, 0);
        build.foe(16.5, float(ty) + 6.5, -4, END_FOES.pick(dice, self.danger), 0.0);
        # From the terrace, the far deck's guards come on.
        terrace = build.touch(12.0, float(ty), -4.0, 20.0, float(ty + 8), 2.0);
        guards = wake_later(build, terrace, 1.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 2.5, 3.5 + float(index) * float(self.wide - 7), 0, END_FOES.pick(dice, self.danger), 180.0, waits=guards);
        }
    }
}

"""A wide bridge over the void, its middle laid with trapdoors that slide
open when the button on the far pillar is shot."""
node TrapdoorBridge(Prefab) {
    has upper: bool = False,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Trapdoor bridge";
        self.source = Q3TOURNEY6;
        self.district = level_district(Q3TOURNEY6);
        self.long = dice.between(32, 34);
        self.wide = dice.between(18, 20);
        self.upper = dice.chance(0.5);
        self.tall = 20;
        self.low = -19;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 4), floor=0), Port(face=3, along=float(self.long - 4), floor=0)];
        if self.upper {
            self.leaves.append(Port(face=0, along=3.5, floor=10));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -18;
        void = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, 0);
        far = self.long - 8;
        deck(build, 1, 1, 8, self.wide - 1, 0, 3);
        deck(build, far, 1, self.long - 1, self.wide - 1, 0, 3);
        # The bridge: firm along both sides, trapdoors down its middle.
        deck(build, 8, middle - 4, far, middle - 1, 0, 3);
        deck(build, 8, middle + 2, far, middle + 5, 0, 3);
        deck(build, 8, middle - 1, 12, middle + 2, 0, 3);
        deck(build, far - 4, middle - 1, far, middle + 2, 0, 3);
        doors = trapdoors(build, 12, middle - 1, far - 4, middle + 2, 0);
        keep_box(build, void, 12, middle - 2, far - 4, middle - 1, 0);
        keep_box(build, void, 12, middle + 2, far - 4, middle + 3, 0);
        # The button on the far pillar, shot to open them.
        build.solid(self.long - 5, middle - 4, 0, self.long - 4, middle - 3, 8);
        late = build.delay(0.5);
        build.push(float(self.long) - 5.0, float(middle) - 3.5, 2.0, 2, True) +>:Fires:+> late;
        late +>:Fires:+> doors;
        build.timer(4.0) +>:Fires:+> build.sparks(float(self.long) - 5.2, float(middle) - 3.5, 5.0, 2);
        # The yard's long pad along the bridge's side, deck to deck.
        throw(build, void, 4.0, 2.5, 0, float(self.long) - 4.0, 2.5, 0, [7, 1, 8, 4], [far, 1, far + 1, 4]);
        build.touch(8.0, float(middle - 4), 0.0, 10.0, float(middle + 5), 6.0, True, "The bridge's middle rests on doors");
        if self.upper {
            # A ledge over the far deck, thrown up to from the bridge; its
            # lip over the bridge's side left open to drop back.
            deck(build, far, 1, self.long - 1, self.wide - 1, 10, 2);
            build.level(void, 10);
            throw(build, void, float(far) - 3.0, float(middle) - 2.5, 0, float(self.long) - 4.0, float(middle) - 2.5, 10, None, [far, middle - 4, far + 1, middle - 1]);
            build.supply(float(self.long) - 3.0, 3.0, 10, "weapon_railgun", "q3");
            build.foe(float(self.long) - 3.0, float(self.wide) - 3.5, 10, END_FOES.pick(dice, self.danger), 180.0);
        }
        void_pads(build, void, 1, 1, self.long - 1, self.wide - 1, low, [[16.0, float(self.wide) - 2.5, 4.0, float(self.wide) - 2.5, 0.0]], [[7, self.wide - 4, 8, self.wide - 1, 0]]);
        build.doorway(void, self.enter);
        for port in self.taken {
            build.doorway(void, port);
        }
        # Foes holding the trapdoors, more coming on from the far deck.
        for index in range(dice.between(2, 3)) {
            build.foe(float(14 + index * 4) + 0.5, py, 0, END_FOES.pick(dice, self.danger), 180.0);
        }
        onto = build.touch(12.0, float(middle - 4), 0.0, 14.0, float(middle + 5), 6.0);
        far_side = wake_later(build, onto, 2.0);
        build.foe(float(self.long) - 2.5, float(middle) + 3.5, 0, END_FOES.pick(dice, self.danger), 180.0, waits=far_side);
        build.supply(float(self.long) - 3.0, float(middle) + 0.5, 0, Q3_HEALTH, "q3");
        build.supply(3.0, 3.0, 0, "ammo_slugs", "q3");
        build.supply(3.0, float(self.wide) - 3.0, 0, Q3_HEALTH, "q3");
    }
}

"""A deck over the void, the BFG's platform high over its far end thrown
up to by a pad (or by way of a perch), a teleporter back down."""
node LaunchSpire(Prefab) {
    has platform: int = 18,
        perch: bool = False,
        tall: int = 28;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Launch spire";
        self.source = Q3TOURNEY6;
        self.district = level_district(Q3TOURNEY6);
        self.long = dice.between(26, 28);
        self.wide = dice.between(22, 24);
        self.platform = dice.between(18, 20);
        self.perch = dice.chance(0.5);
        self.tall = self.platform + 10;
        self.low = -19;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.platform), Port(face=1, along=8.0, floor=0), Port(face=3, along=8.0, floor=0), Port(face=0, along=4.0, floor=self.platform)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        py = float(middle) + 0.5;
        low = -18;
        hz = self.platform;
        void = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, 0);
        build.level(void, hz);
        deck(build, 1, 3, self.long - 9, self.wide - 3, 0, 3);
        deck(build, 6, 1, 10, 3, 0, 3);
        deck(build, 6, self.wide - 3, 10, self.wide - 1, 0, 3);
        px = self.long - 11;
        deck(build, px, 1, self.long - 1, self.wide - 1, hz, 2);
        throw(build, void, float(px) - 6.0, py, 0, float(self.long) - 5.0, py, hz, None, [px, middle - 2, px + 1, middle + 3]);
        if self.perch {
            half = hz // 2;
            build.level(void, half);
            deck(build, px - 8, 3, px - 2, 9, half, 2);
            throw(build, void, float(px) - 11.0, 6.0, 0, float(px) - 6.5, 6.0, half, None, [px - 8, 4, px - 7, 8]);
            throw(build, void, float(px) - 5.0, 6.0, half, float(px) + 3.0, 6.0, hz, None, [px, 4, px + 1, 8]);
            build.supply(float(px) - 6.0, 4.5, half, Q3_ARMOR, "q3");
        }
        build.teleporter(float(self.long) - 3.0, float(self.wide) - 3.5, hz, 4.0, py, 0, 0.0);
        void_pads(build, void, 1, 1, self.long - 1, self.wide - 1, low, [[13.0, 2.0, 8.0, 2.0, 0.0], [13.0, float(self.wide) - 2.0, 8.0, float(self.wide) - 2.0, 0.0]], [[9, 1, 10, 3, 0], [9, self.wide - 3, 10, self.wide - 1, 0]]);
        build.doorway(void, self.enter);
        for port in self.taken {
            build.doorway(void, port);
        }
        build.timer(5.0) +>:Fires:+> build.sparks(float(px) + 0.5, float(middle) + 0.5, float(hz) - 2.5, 3);
        build.supply(float(self.long) - 4.0, 3.5, hz, "weapon_bfg", "q3");
        build.supply(float(self.long) - 6.0, 3.5, hz, "ammo_bfg", "q3");
        build.foe(10.5, py + 3.0, 0, END_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(px) - 2.5, py - 4.0, 0, END_FOES.pick(dice, self.danger), 180.0);
        # Landing up top, a moment on, what waits there turns.
        top = build.touch(float(px), 1.0, float(hz), float(px + 4), float(self.wide - 1), float(hz + 6));
        guards = wake_later(build, top, 1.0);
        build.foe(float(self.long) - 2.5, py + 3.0, hz, END_FOES.pick(dice, self.danger, True), 180.0, waits=guards);
        build.supply(float(self.long) - 3.0, py - 3.0, hz, Q3_HEALTH, "q3");
        build.supply(3.0, py, 0, Q3_HEALTH, "q3");
        build.supply(float(px) - 3.0, py + 4.0, 0, Q3_HEALTH, "q3");
    }
}

"""The hub: a cross of decks over the void, a dais at the crossing,
terraces low between the arms, trapdoors along one arm."""
node VoidCross(Prefab) {
    has both: bool = False,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Void cross";
        self.source = Q3TOURNEY6;
        self.district = level_district(Q3TOURNEY6);
        self.long = dice.between(32, 34);
        self.wide = dice.between(30, 32);
        self.both = dice.chance(0.5);
        self.tall = 16;
        self.low = -19;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        cx = float(self.long // 2);
        self.enter = Port(face=2, along=cy + 0.5, floor=0);
        self.leaves = [Port(face=0, along=cy + 0.5, floor=0), Port(face=1, along=cx + 0.5, floor=0), Port(face=3, along=cx + 0.5, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        low = -18;
        hub = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(hub, 0);
        build.level(hub, -12);
        build.level(hub, 2);
        # The cross of decks, the dais at the crossing.
        deck(build, 1, cy - 3, self.long - 1, cy + 4, 0, 3);
        deck(build, cx - 3, 1, cx + 4, self.wide - 1, 0, 3);
        build.solid(cx - 2, cy - 2, 0, cx + 3, cy + 3, 2);
        stair(build, cx - 4, cy - 1, 0, 0, 2, 3);
        stair(build, cx + 4, cy - 1, 0, 2, 2, 3);
        columns(build, [[cx - 2, cy - 2], [cx + 2, cy + 2]], 2, 9);
        # The terraces low in the quarters between the arms: a pad up from
        # each to the arm, a drop off the arm's edge down to each.
        quarters = [[0, 0], [1, 1]] if self.both else [[0, 0]];
        for q in quarters {
            x0 = 4 if q[0] == 0 else cx + 7;
            x1 = cx - 6 if q[0] == 0 else self.long - 4;
            y0 = 3 if q[1] == 0 else cy + 7;
            y1 = cy - 6 if q[1] == 0 else self.wide - 3;
            deck(build, x0, y0, x1, y1, -12, 2);
            tx = float(x0 + x1) * 0.5;
            if q[1] == 0 {
                throw(build, hub, tx, float(y1) - 2.5, -12, tx, float(cy) + 0.5, 0, None, [int(tx) - 2, cy - 3, int(tx) + 3, cy - 2]);
                keep_box(build, hub, x0 + 1, cy - 3, x0 + 4, cy - 2, 0);
            } else {
                throw(build, hub, tx, float(y0) + 2.5, -12, tx, float(cy) + 0.5, 0, None, [int(tx) - 2, cy + 3, int(tx) + 3, cy + 4]);
                keep_box(build, hub, x1 - 4, cy + 3, x1 - 1, cy + 4, 0);
            }
            build.foe(tx, float(y0 + y1) * 0.5, -12, END_FOES.pick(dice, self.danger), 90.0);
            build.supply(tx + 2.0, float(y0 + y1) * 0.5, -12, Q3_HEALTH, "q3");
        }
        # Trapdoors along the far arm, a button on the dais shot to open them.
        build.widen(hub, cx + 7, cy - 1, -3, self.long - 6, cy + 2, 0);
        doors = trapdoors(build, cx + 7, cy - 1, self.long - 6, cy + 2, 0);
        keep_box(build, hub, cx + 7, cy - 2, self.long - 6, cy - 1, 0);
        keep_box(build, hub, cx + 7, cy + 2, self.long - 6, cy + 3, 0);
        late = build.delay(0.5);
        build.push(float(cx) + 3.0, float(cy) + 2.5, 4.0, 0, True) +>:Fires:+> late;
        late +>:Fires:+> doors;
        # A pad from the +y arm's end over the corner of the void to the +x
        # arm's end.
        throw(build, hub, float(cx) + 0.5, float(self.wide) - 7.0, 0, float(self.long) - 4.0, float(cy) + 2.0, 0, None, None);
        void_pads(build, hub, 1, 1, self.long - 1, self.wide - 1, low, [[float(cx) + 10.0, 5.0, float(cx) + 0.5, 5.0, 0.0], [float(cx) - 10.0, float(self.wide) - 5.0, float(cx) + 0.5, float(self.wide) - 5.0, 0.0]], [[cx + 3, 3, cx + 4, 8, 0], [cx - 3, self.wide - 8, cx - 2, self.wide - 3, 0]]);
        build.doorway(hub, self.enter);
        for port in self.taken {
            build.doorway(hub, port);
        }
        build.supply(float(cx) + 0.5, float(cy) + 0.5, 2, "item_health_mega", "q3");
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx + 9 + index * 4) + 0.5, float(cy) + 0.5, 0, END_FOES.pick(dice, self.danger), 180.0);
        }
        build.foe(float(cx) + 0.5, 4.0, 0, END_FOES.pick(dice, self.danger), 90.0, patrol=[[float(cx) + 0.5, 4.0], [float(cx) + 0.5, float(self.wide) - 4.0]]);
        # Up on the dais, the far arms' guards come on.
        dais = build.touch(float(cx - 2), float(cy - 2), 2.0, float(cx + 3), float(cy + 3), 8.0);
        guards = wake_later(build, dais, 1.5);
        build.foe(float(cx) + 0.5, float(self.wide) - 3.0, 0, END_FOES.pick(dice, self.danger), 270.0, waits=guards);
        build.foe(float(self.long) - 3.0, float(cy) + 2.5, 0, END_FOES.pick(dice, self.danger), 180.0, waits=guards);
        build.timer(6.0) +>:Fires:+> build.sparks(float(cx) - 1.8, float(cy) - 1.5, 5.0, 2);
        build.supply(3.0, float(cy) - 1.5, 0, Q3_HEALTH, "q3");
        build.supply(float(self.long) - 3.0, float(cy) - 1.5, 0, Q3_HEALTH, "q3");
        build.supply(float(cx) + 0.5, 3.0, 0, "ammo_rockets", "q3");
    }
}

"""The key room: a pad down to an island, a platform bobbing up from it to
the altar, the key there."""
node XaeroAltar(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 20,
        side: int = 0,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Xaero's altar (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = Q3TOURNEY6;
        self.district = level_district(Q3TOURNEY6);
        self.long = dice.between(28, 30);
        self.hall_wide = dice.between(20, 22);
        self.wide = self.hall_wide + 4;
        self.side = dice.below(2);
        self.tall = 18;
        self.low = -19;
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
        low = -18;
        room = build.room(1, 1, low, self.long - 1, side, self.tall, variant=dice.below(3), sky=True);
        for z in [0, -4, 8] {
            build.level(room, z);
        }
        build.doorway(room, self.enter);
        deck(build, 1, 1, 11, side, 0, 3);
        my = 3 if self.side == 0 else side - 9;
        deck(build, 14, my, 20, my + 6, -4, 2);
        throw(build, room, 8.0, float(my) + 3.0, 0, 16.0, float(my) + 3.0, -4, [10, my + 1, 11, my + 5], [14, my + 1, 15, my + 5]);
        # The platform bobbing from the island up to the altar.
        build.train([4.0, 4.0, 1.0], [[20.0, float(my + 1), -5.0], [20.0, float(my + 1), 7.0]], 70.0, 2.0);
        keep_box(build, room, 19, my + 1, 20, my + 5, -4);
        keep_box(build, room, 24, my + 1, 25, my + 5, 8);
        deck(build, 24, my - 1, self.long - 2, my + 7, 8, 2);
        build.teleporter(float(self.long) - 3.5, float(my) + 5.0, 8, 4.0, float(cy) + 0.5, 0, 0.0);
        open_y = float(side) - 3.0 if self.side == 0 else 4.0;
        void_pads(build, room, 1, 1, self.long - 1, side, low, [[17.0, open_y, 6.0, open_y, 0.0]], [[10, int(open_y) - 1, 11, int(open_y) + 2, 0]]);
        key_ambush(build, self.key, float(self.long) - 5.0, float(my) + 1.5, 8, side, 0, [2, 7], [END_FOES.pick(dice, self.danger, True), END_FOES.pick(dice, self.danger)]);
        build.foe(26.5, float(my) + 5.0, 8, END_FOES.pick(dice, self.danger), 180.0);
        build.foe(17.0, float(my) + 1.5, -4, END_FOES.pick(dice, self.danger), 180.0);
        build.timer(5.0) +>:Fires:+> build.sparks(float(self.long) - 2.0, float(my) + 3.0, 9.0, 2);
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(15.0, float(my) + 4.5, -4, Q3_HEALTH, "q3");
    }
}

"""The end (or a gate): a hall, a deck over the void, a pad over to the
last platform, the way out in an alcove behind a door a button opens."""
node VeryEnd(Prefab) {
    has key: str = "",
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Very end" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = Q3TOURNEY6;
        self.district = level_district(Q3TOURNEY6);
        self.long = dice.between(32, 34);
        self.wide = dice.between(18, 20);
        self.tall = 14;
        self.low = -19;
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
        low = -18;
        wall = 7;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        void = build.room(wall + 1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(void, 0);
        build.doorway(hall, self.enter);
        build.widen(void, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        ex = wall + 8;
        deck(build, wall + 1, 1, ex, self.wide - 1, 0, 3);
        lx = self.long - 10;
        deck(build, lx, 1, self.long - 1, self.wide - 1, 0, 3);
        throw(build, void, float(ex) - 2.5, py - 3.0, 0, float(lx) + 3.5, py - 3.0, 0, [ex - 1, middle - 5, ex, middle - 1], [lx, middle - 5, lx + 1, middle - 1]);
        # The alcove behind its wall, the door shot open by its button.
        ax = self.long - 4;
        build.solid(ax, 1, 0, ax + 1, self.wide - 1, self.tall);
        build.widen(void, ax, middle - 2, 0, ax + 1, middle + 2, 8);
        opened = build.opened(float(ax), float(middle - 2), 0.0, float(ax + 1), float(middle + 2), 8.0);
        late = build.delay(0.5);
        build.push(float(ax), float(middle) + 4.0, 3.0, 2, True) +>:Fires:+> late;
        late +>:Fires:+> opened;
        build.timer(4.5) +>:Fires:+> build.sparks(float(ax) - 0.2, float(middle) - 4.0, 5.0, 2);
        build.way_out(float(self.long) - 2.0, py, 0);
        void_pads(build, void, wall + 1, 1, self.long - 1, self.wide - 1, low, [[float(ex) + 3.5, 3.0, float(ex) - 3.5, 3.0, 0.0]], [[ex - 1, 2, ex, 5, 0]]);
        door = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        guards = wake_later(build, door, 1.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(lx) + 3.5, 3.5 + float(index) * float(self.wide - 7) / 2.0, 0, END_FOES.pick(dice, self.danger), 180.0, waits=guards);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, END_FOES.pick(dice, self.danger), 180.0);
        }
        build.supply(2.5, 2.5, 0, Q3_HEALTH, "q3");
        build.supply(float(lx) + 2.0, float(self.wide) - 2.5, 0, Q3_HEALTH, "q3");
    }
}

"""q3tourney6's stretches: [name, role]."""
glob Q3TOURNEY6_STRETCHES: list[list[str]] = [
         ["platform", "start"],
         ["trapdoors", "flow"],
         ["launch", "flow"],
         ["cross", "hub"],
         ["cross", "flow"],
         ["altar", "keyroom"],
         ["end", "end"],
         ["end", "gate"]
     ];

"""One of q3tourney6's stretches by its name."""
def make_q3tourney6(name: str, key: str) -> Prefab {
    if name == "platform" {
        return EndPlatform();
    }
    if name == "trapdoors" {
        return TrapdoorBridge();
    }
    if name == "launch" {
        return LaunchSpire();
    }
    if name == "cross" {
        return VoidCross();
    }
    if name == "altar" {
        return XaeroAltar(key=key if key else "key_silver");
    }
    return VeryEnd(key=key);
}
