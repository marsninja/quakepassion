"""Prefabs drawn from e2m3, the Crypt of Decay: crypts of copper and stone
over deep water, a well of wishes, walkways over cisterns and pits, a hall
crossed by bridges over a flooded pit, a crypt whose walls open on its
dead a moment after its button is pressed, the gold key in a vault below.
Raised in e2m3's own palette. Each stretch takes its shape from its dice
as well as its sizes.

- `CryptGate`: the start. A nave sunk between buttresses, a gallery over
  the north bays up a stair, a way on from it; the dead in the bays wake
  as the nave is crossed; the Well of Wishes at the near end, deep water
  with a secret at its bottom ("Welcome to the Well of Wishes!").
- `Cistern`: a walkway over a deep cistern and a dry pit beyond its dam;
  the walkway's far span always there, or drawn up by a button on the near
  floor ("This door opens nearby...") or by a drop into the pit; the drop
  wakes the pit's dead and opens a cache in its wall; a lift back up.
- `BridgeHall`: the hub: a hall round a pit, bridges across it crossing
  in its middle, a deep pool in the pit's floor, lifts up out of it,
  galleries over the ledges; the side ways on opened by a button on the
  far ledge; foes sent in as the crossing is reached.
- `DecayCrypt`: a crypt, a tomb raised in its middle with the button on
  it, a channel of water across its near end, a gallery over its north
  wall; the button opens the door on
  at once and, a moment later, the secret doors of the alcoves in its
  walls on the dead behind them (e2m3's delayed walls of zombies).
- `KnightVault`: the key room: a vault down a stair from a ledge, a
  gallery over the stair, the key on a bier; taking it opens the closets
  and sends one more in behind.
- `CryptExit`: the end: a hall, a door (a key's, as a gate, or one that
  opens as it is neared), a stair up to a gallery and the slipgate on it,
  a pool under the gallery."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, lift, apart }
import from .e1m2_parts { slab, keep_box, keep_ring, arcade, stash, closets, key_cue, flood, sump }
import from .e1m2 { port_gate }

glob E2M3: str = "q1:e2m3";

"""e2m3's foes: the dead and ogres, hell knights growing with the danger."""
def e2m3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre"] if heavy else ["monster_zombie", "monster_zombie", "monster_ogre"], ["monster_hell_knight"], danger));
}

"""Alcoves behind secret doors in a wall (its air ending at the cell line y
`line`, the alcoves beyond it the way `toward` goes, +1 or -1), at each of
`starts`, on lift `z`: each door opens (back, then aside) when `cue`
fires, and what lies in the alcove wakes with it."""
def secret_alcoves(build: Raising, cue: Cue, line: int, starts: list[int], z: int, toward: int, kinds: list[str]) {
    woken = build.waiting();
    cue +>:Fires:+> woken;
    for (index, at) in enumerate(starts) {
        if toward > 0 {
            build.room(at, line + 1, z, at + 3, line + 4, z + 6);
            fields = {"classname": "func_door_secret", "angle": str(build.facing(1)), "sounds": "1"};
            build.put_box(fields, float(at), float(line), float(z), float(at + 3), float(line + 1), float(z + 5), kit_of(build.district).wall);
            build.rock_round(float(at - 4), float(line - 4), float(z), float(at + 7), float(line + 5), float(z + 6));
            spot = float(line) + 2.5;
            facing = 270.0;
        } else {
            build.room(at, line - 4, z, at + 3, line - 1, z + 6);
            fields = {"classname": "func_door_secret", "angle": str(build.facing(3)), "sounds": "1"};
            build.put_box(fields, float(at), float(line - 1), float(z), float(at + 3), float(line), float(z + 5), kit_of(build.district).wall);
            build.rock_round(float(at - 4), float(line - 5), float(z), float(at + 7), float(line + 4), float(z + 6));
            spot = float(line) - 2.5;
            facing = 90.0;
        }
        cue +>:Fires:+> build.cue([fields], "wall");
        build.foe(float(at) + 1.5, spot, z, kinds[index % len(kinds)], facing, waits=woken);
    }
}

"""The start: a nave sunk between buttresses, a gallery over the north
bays, the Well of Wishes."""
node CryptGate(Prefab) {
    has tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crypt gate";
        self.source = E2M3;
        self.district = level_district(E2M3);
        self.long = dice.between(26, 30);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(16, 18);
        self.low = -17;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=0, along=float(self.wide - 3), floor=7), Port(face=3, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        nave = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(nave, -2);
        build.level(nave, 7);
        # The sunken nave, two steps down at each end.
        build.widen(nave, 7, 4, -2, self.long - 7, self.wide - 4, 0);
        stair(build, 8, 4, -2, 2, 2, self.wide - 8);
        stair(build, self.long - 9, 4, -2, 0, 2, self.wide - 8);
        # Buttresses along the side walls, bays between them; the north ones
        # under the gallery.
        clear = [[0, middle - 3, 7, middle + 3], [0, 0, 7, 6], [self.long - 7, 0, self.long, 4], [self.long - 7, self.wide - 4, self.long, self.wide]];
        pillars(build, 4, 1, self.long - 6, 2, 0, self.tall, 3, clear);
        pillars(build, 13, self.wide - 2, self.long - 6, self.wide - 1, 0, 6, 3, clear);
        # The gallery over the north bays, a stair up to it at the near end,
        # a way on from its far end.
        slab(build, 11, self.wide - 4, self.long - 1, self.wide - 1, 7);
        stair(build, 4, self.wide - 4, 0, 0, 7, 3);
        keep_box(build, nave, 9, self.wide - 5, 12, self.wide - 1, 7);
        # The Well of Wishes: deep water at the near end, its rim bare, a
        # secret at its bottom.
        build.room(2, 1, -15, 5, 4, 0);
        flood(build, 2, 1, -15, 5, 4, -1);
        keep_box(build, nave, 1, 1, 6, 5, 0);
        build.touch(2.0, 1.0, 0.0, 5.0, 4.0, 4.0, False, "Welcome to the Well of Wishes!");
        build.secret(2.0, 1.0, -15.0, 5.0, 4.0, -12.0);
        build.supply(3.5, 2.5, -15, "item_artifact_super_damage");
        build.doorway(nave, self.enter);
        for port in self.taken {
            build.doorway(nave, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) + 2.5, 0, "item_shells");
        # The dead in the bays wake as the nave's middle is reached.
        crossing = build.touch(float(self.long // 2 - 1), 4.0, -2.0, float(self.long // 2 + 2), float(self.wide - 4), 4.0);
        bays = build.waiting();
        crossing +>:Fires:+> bays;
        for index in range(dice.between(2, 3)) {
            build.foe(float(5 + index * 3) + 0.5, 1.5 if index % 2 == 0 else float(self.wide) - 1.5, 0, "monster_zombie", 0.0, waits=bays);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, -2, e2m3_foe(dice, self.danger), 180.0);
        build.foe(13.5, float(self.wide) - 2.5, 7, "monster_ogre", 0.0, patrol=[[13.5, float(self.wide) - 2.5], [float(self.long) - 3.5, float(self.wide) - 2.5]]);
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_health");
        build.supply(float(self.long) - 3.5, float(self.wide) - 2.5, 7, "item_shells");
    }
}

"""A walkway over a deep cistern and a dry pit beyond its dam."""
node Cistern(Prefab) {
    has tall: int = 16,
        drawn: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cistern";
        self.source = E2M3;
        self.district = level_district(E2M3);
        self.long = dice.between(30, 34);
        self.wide = dice.between(15, 17);
        self.tall = dice.between(16, 18);
        self.drawn = dice.chance(0.5);
        self.low = -20;
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
        build.level(hall, -10);
        x0 = 7;
        x1 = self.long - 7;
        xm = x0 + (x1 - x0) // 2;
        # The cistern: deep water, steps up out of it, a well in its bed.
        build.pool(x0, 1, -14, xm, self.wide - 1, 0, 2);
        sump(build, xm - 4, 2, -19, -14, 3);
        # The dry pit beyond the dam, ten lifts down, a lift back up to the
        # far floor.
        pit = build.room(xm + 1, 1, -10, x1, self.wide - 1, 0);
        lift(build, x1 - 3, self.wide - 4, x1, self.wide - 1, -10, 0);
        keep_box(build, hall, x1 - 4, self.wide - 5, x1 + 1, self.wide - 1, 0);
        keep_box(build, hall, x1 - 4, self.wide - 5, x1, self.wide - 1, -10);
        landed = build.touch(float(xm + 1), 1.0, -10.0, float(x1), float(self.wide - 1), -6.0);
        # The walkway over both, three cells wide, piers down into the water;
        # its span over the pit always there, or its middle drawn up by the
        # button (the pit open under its ends).
        slab(build, x0, middle - 1, xm + 1, middle + 2, 0);
        if self.drawn {
            slab(build, xm + 1, middle - 1, xm + 3, middle + 2, 0);
            slab(build, x1 - 2, middle - 1, x1, middle + 2, 0);
            span = build.drawn(float(xm + 3), float(middle - 1), float(x1 - 2), float(middle + 2), 0, 11);
            build.solid(x0 - 2, middle + 3, 0, x0 - 1, middle + 4, 4);
            build.push(float(x0 - 1), float(middle) + 3.5, 1.3, 0) +>:Fires:+> span;
            # Down in the pit, the span is drawn up too: the way back over.
            landed +>:Fires:+> span;
            build.touch(1.0, 1.0, 0.0, float(x0 - 2), float(self.wide - 1), 6.0, True, "This door opens nearby...");
        } else {
            slab(build, xm + 1, middle - 1, x1, middle + 2, 0);
        }
        for x in range(x0 + 6, xm - 1, 5) {
            build.solid(x, middle - 1, -14, x + 1, middle, -1);
            build.solid(x, middle + 1, -14, x + 1, middle + 2, -1);
        }
        for y in range(middle - 1, middle + 2) {
            build.keep(hall, x0 - 1, y, 0);
            build.keep(hall, x1, y, 0);
            build.keep(hall, xm, y, 0);
        }
        # The walkway's edge over the pit bare, to drop from.
        keep_box(build, hall, xm + 2, middle - 1, x1 - 1, middle, 0);
        # A drop into the pit wakes its dead and opens a cache in the far
        # wall's rock.
        below = build.waiting();
        landed +>:Fires:+> below;
        build.room(x1 + 1, 3, -10, x1 + 3, 6, -6);
        cache = {"classname": "func_door_secret", "angle": str(build.facing(0)), "sounds": "1"};
        build.put_box(cache, float(x1), 3.0, -10.0, float(x1 + 1), 6.0, -6.0, kit_of(build.district).wall);
        build.rock_round(float(x1 - 3), 0.0, -10.0, float(x1 + 5), 9.0, -5.0);
        landed +>:Fires:+> build.cue([cache], "wall");
        build.secret(float(x1 + 1), 3.0, -10.0, float(x1 + 3), 6.0, -7.0);
        build.supply(float(x1) + 2.0, 4.5, -10, "item_armor2");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 8 + index * 6) + 0.5, 3.5, -12, "monster_fish", 90.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(xm + 2 + index * 2) + 0.5, 3.5, -10, "monster_zombie", 0.0, waits=below);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(x1) + 2.5, 2.5 + float(index) * 4.0, 0, e2m3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(2.5, 2.5, 0, "monster_zombie", 90.0, patrol=[[2.5, 2.5], [2.5, float(self.wide) - 2.5]]);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(xm) + 2.5, float(self.wide) - 2.5, -10, "item_rockets");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_health");
    }
}

"""The hub: a hall round a pit, bridges across it crossing in its middle, a
deep pool in the pit's floor, lifts, galleries over the ledges."""
node BridgeHall(Prefab) {
    has pit: int = 6,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Bridge hall";
        self.source = E2M3;
        self.district = level_district(E2M3);
        self.long = dice.between(26, 30);
        self.wide = dice.between(26, 30);
        self.tall = dice.between(18, 20);
        self.pit = dice.between(6, 7);
        self.low = -self.pit - 14;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=1, along=float(self.long // 2), floor=0), Port(face=0, along=middle, floor=0), Port(face=3, along=float(self.long // 2), floor=0), Port(face=0, along=float(self.wide - 3), floor=8)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        low = -self.pit;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, low);
        build.level(hall, 8);
        build.widen(hall, 6, 6, low, self.long - 6, self.wide - 6, 0);
        # The deep pool in the pit's floor, a well in its bed.
        build.pool(cx - 4, cy - 4, low - 8, cx + 4, cy + 4, low, 2);
        sump(build, cx + 1, cy + 1, low - 13, low - 8, 2);
        # Lifts up out of the pit in two corners, waiting at their feet.
        for corner in [[6, 6], [self.long - 8, self.wide - 8]] {
            build.put_box({"classname": "func_plat", "height": str(self.pit * 16), "speed": "200"}, float(corner[0]), float(corner[1]), -0.5, float(corner[0] + 2), float(corner[1] + 2), 0.0, kit_of(build.district).step);
        }
        # The bridges, crossing in the middle.
        build.solid(6, cy - 2, -1, self.long - 6, cy + 2, 0);
        build.solid(cx - 2, 6, -1, cx + 2, self.wide - 6, 0);
        for at in range(-2, 2) {
            build.keep(hall, 5, cy + at, 0);
            build.keep(hall, self.long - 6, cy + at, 0);
            build.keep(hall, cx + at, 5, 0);
            build.keep(hall, cx + at, self.wide - 6, 0);
        }
        # Galleries over the south and north ledges, lifts up to them on the
        # west ledge, a way on from the north one's far end.
        slab(build, 6, 1, self.long - 1, 5, 8);
        slab(build, 6, self.wide - 5, self.long - 1, self.wide - 1, 8);
        lift(build, 2, 2, 5, 5, 0, 8);
        lift(build, 2, self.wide - 5, 5, self.wide - 2, 0, 8);
        keep_box(build, hall, 1, 1, 7, 6, 8);
        keep_box(build, hall, 1, self.wide - 6, 7, self.wide - 1, 8);
        keep_box(build, hall, 1, 1, 6, 6, 0);
        keep_box(build, hall, 1, self.wide - 6, 6, self.wide - 1, 0);
        # The side ways on open from the button on the far ledge.
        press = build.push(float(self.long - 1), float(cy) + 3.5, 1.2, 2);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.face != 0 {
                press +>:Fires:+> port_gate(build, self.long, self.wide, port);
            }
        }
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0, True, "This door opens nearby...");
        # Foes (one heavy) are sent onto the ledges as the crossing is reached.
        crossing = build.touch(float(cx - 2), float(cy - 2), 0.0, float(cx + 2), float(cy + 2), 6.0);
        crossing +>:Fires:+> build.summon(2, cy - 1, low - 12, e2m3_foe(dice, self.danger, True), 3.0, float(cy) + 3.5, 0, 0.0);
        crossing +>:Fires:+> build.summon(self.long - 5, cy - 1, low - 12, e2m3_foe(dice, self.danger), float(self.long) - 3.0, float(cy) - 3.5, 0, 180.0);
        roused = build.waiting();
        crossing +>:Fires:+> roused;
        for index in range(dice.between(1, 2)) {
            build.foe(float(8 + index * 4) + 0.5, float(cy) + 5.5, low, e2m3_foe(dice, self.danger), 0.0, waits=roused);
        }
        build.foe(float(cx) + 0.5, float(cy) - 4.5, 0, e2m3_foe(dice, self.danger, True), 270.0);
        build.foe(8.5, 3.0, 8, "monster_ogre", 0.0, patrol=[[8.5, 3.0], [float(self.long) - 3.5, 3.0]]);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.0, 8, "monster_zombie", 180.0, patrol=[[float(self.long) - 3.5, float(self.wide) - 3.0], [8.5, float(self.wide) - 3.0]]);
        build.foe(float(cx) - 2.5, float(cy) + 0.5, low - 6, "monster_fish", 0.0);
        build.supply(3.0, 3.0, 8, "item_health");
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, 8, "item_health");
        build.supply(8.5, float(cy) - 5.5, low, "item_health");
        build.supply(float(self.long) - 9.0, float(cy) + 5.5, low, "item_spikes");
        build.supply(3.0, float(self.wide) - 3.0, 0, "item_shells");
        build.supply(3.0, float(cy) + 3.5, 0, "item_health");
    }
}

"""A crypt, a tomb raised in its middle with the button on it, a channel of
water across its near end; alcoves behind secret doors in its walls."""
node DecayCrypt(Prefab) {
    has hw: int = 16,
        tall: int = 14,
        shot: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Decay crypt";
        self.source = E2M3;
        self.district = level_district(E2M3);
        self.long = dice.between(28, 32);
        self.hw = dice.between(16, 18);
        self.wide = self.hw + 8;
        self.tall = dice.between(14, 16);
        self.shot = dice.chance(0.4);
        self.low = -12;
        self.high = self.tall + 1;
        mid = (5 + self.wide - 5) // 2;
        self.enter = Port(face=2, along=float(mid), floor=0);
        self.leaves = [Port(face=0, along=float(mid - 3), floor=0), Port(face=0, along=float(mid + 3), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        y0 = 5;
        y1 = self.wide - 5;
        mid = (y0 + y1) // 2;
        door_x = self.long - 6;
        hall = build.room(1, y0, 0, door_x, y1, self.tall, variant=dice.below(3));
        chamber = build.room(door_x + 1, y0, 0, self.long - 1, y1, 10, variant=dice.below(3));
        # The channel of water across the near end, a causeway over it, steps
        # out of it on both sides, a well in its bed.
        build.pool(5, y0, -6, 9, y1, 0, 2, False, True, True);
        build.solid(5, mid - 2, -6, 9, mid + 2, 0);
        keep_box(build, hall, 4, mid - 2, 10, mid + 2, 0);
        sump(build, 6, mid + 3, -11, -6, 2);
        # The tomb, two lifts up, a step round it, the button on its
        # sarcophagus (or high on the far wall, to be shot).
        cx = self.long // 2;
        build.solid(cx - 4, mid - 3, 0, cx + 4, mid + 4, 1);
        build.solid(cx - 3, mid - 2, 1, cx + 3, mid + 3, 2);
        build.solid(cx - 1, mid, 2, cx + 1, mid + 1, 4);
        if self.shot {
            press = build.push(float(door_x), float(mid) + 4.5, 9.0, 2, True);
        } else {
            press = build.push(float(cx + 1), float(mid) + 0.5, 2.5, 0);
        }
        # A gallery along the north wall over the alcoves, a lift up to it
        # past the channel.
        slab(build, 13, y1 - 3, door_x, y1, 7);
        lift(build, 10, y1 - 3, 13, y1, 0, 7);
        keep_box(build, hall, 10, y1 - 4, 15, y1, 7);
        keep_box(build, hall, 9, y1 - 4, 14, y1, 0);
        # The door on opens at once ("This door opens nearby...").
        build.widen(chamber, door_x, mid - 2, 0, door_x + 1, mid + 2, 8);
        press +>:Fires:+> build.opened(float(door_x), float(mid - 2), 0.0, float(door_x + 1), float(mid + 2), 8.0);
        build.touch(float(door_x - 3), float(mid - 2), 0.0, float(door_x), float(mid + 2), 6.0, True, "This door opens nearby...");
        # A moment later the alcoves in both walls open on their dead.
        later = build.delay(4.0);
        press +>:Fires:+> later;
        starts = [x for x in [11, 16, 21, 26] if x + 3 <= door_x - 1];
        secret_alcoves(build, later, y0, starts[:3], 0, -1, ["monster_zombie", "monster_zombie", e2m3_foe(dice, self.danger, True)]);
        secret_alcoves(build, later, y1, starts[1:], 0, 1, ["monster_zombie", e2m3_foe(dice, self.danger)]);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(chamber, port);
        }
        # Crossing the causeway wakes the crypt's ogre; a hell knight waits
        # beyond the door.
        crossing = build.touch(5.0, float(mid - 2), 0.0, 9.0, float(mid + 2), 6.0);
        guard = build.waiting();
        crossing +>:Fires:+> guard;
        build.foe(float(cx) + 4.5, float(mid) + 5.5, 0, e2m3_foe(dice, self.danger, True), 180.0, waits=guard);
        build.foe(float(self.long) - 2.5, float(mid) + 0.5, 0, e2m3_foe(dice, self.danger, True), 180.0, waits=guard);
        build.foe(12.5, float(y0) + 1.5, 0, "monster_zombie", 0.0, patrol=[[12.5, float(y0) + 1.5], [float(door_x) - 2.5, float(y0) + 1.5]]);
        build.foe(7.0, float(mid) + 5.5, -5, "monster_fish", 0.0);
        build.foe(15.5, float(y1) - 1.5, 7, e2m3_foe(dice, self.danger), 0.0, patrol=[[15.5, float(y1) - 1.5], [float(door_x) - 1.5, float(y1) - 1.5]]);
        build.supply(2.5, float(y0) + 1.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(y1) - 1.5, 0, "item_rockets");
        build.supply(float(door_x) - 1.5, float(y1) - 1.5, 7, "item_health");
    }
}

"""The key room: a vault down a stair from a ledge, a gallery over the
ledge, the key on a bier; taking it opens the closets."""
node KnightVault(Prefab) {
    has key: str = "key_gold",
        hall_wide: int = 18,
        deep: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Knight vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M3;
        self.district = level_district(E2M3);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(5, 6);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 10;
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
        low = -self.deep;
        vault = build.room(1, 1, low, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, 0);
        build.level(vault, 6);
        build.doorway(vault, self.enter);
        # The ledge in at the near end, a stair down off it; a gallery along
        # the south wall at the ledge's height plus six, a lift up to it.
        build.solid(1, 1, low, 6, side, 0);
        stair(build, 6 + self.deep - 1, cy - 2, low, 2, self.deep, 4);
        for y in range(cy - 2, cy + 2) {
            build.keep(vault, 5, y, 0);
        }
        slab(build, 4, 1, self.long - 1, 4, 6);
        lift(build, 1, 1, 4, 4, 0, 6);
        keep_box(build, vault, 1, 1, 6, 5, 6);
        keep_box(build, vault, 1, 1, 5, 5, 0);
        # The bier at the far end, the key on it.
        build.solid(self.long - 6, cy - 1, low, self.long - 3, cy + 2, low + 1);
        pillars(build, 9 + self.deep, 5, self.long - 7, 6, low, self.tall, 4, []);
        pillars(build, 9 + self.deep, side - 4, self.long - 7, side - 3, low, self.tall, 4, []);
        taken = key_cue(build, self.key, float(self.long) - 4.5, float(cy) + 0.5, low + 1);
        closets(build, taken, side, [7 + self.deep, self.long - 7], low, 1, ["monster_shambler" if self.danger > 0.85 else e2m3_foe(dice, self.danger, True), "monster_zombie"]);
        taken +>:Fires:+> build.summon(2, cy - 1, low - 9, e2m3_foe(dice, self.danger), 3.0, float(cy) + 0.5, 0, 0.0);
        stash(build, 6, cy + 2, low, 2, "item_armor2");
        build.foe(float(self.long) - 2.5, 5.5, low, e2m3_foe(dice, self.danger, True), 180.0);
        build.foe(float(self.long // 2) + 0.5, float(cy) + 3.5, low, "monster_zombie", 180.0);
        build.foe(8.5, 2.5, 6, "monster_ogre", 0.0, patrol=[[8.5, 2.5], [float(self.long) - 3.5, 2.5]]);
        build.supply(2.5, float(side) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 4.5, float(cy) - 2.5, low, "item_health");
        build.supply(float(self.long) - 4.5, float(cy) + 3.5, low, "item_shells");
    }
}

"""The end: a hall, a door (a key's, as a gate, or one that opens as it is
neared), a stair up to a gallery and the slipgate on it."""
node CryptExit(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crypt exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M3;
        self.district = level_district(E2M3);
        self.long = dice.between(26, 28);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(16, 18);
        self.low = -12;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = self.long - 15;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 12, variant=dice.below(3));
        chapel = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(chapel, 6);
        build.doorway(hall, self.enter);
        build.widen(chapel, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        near = build.touch(float(wall - 3), float(middle - 2), 0.0, float(wall), float(middle + 2), 6.0);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        } else {
            near +>:Fires:+> build.opened(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0);
        }
        # A stair up to the gallery and the slipgate on it; a pool under the
        # gallery's front.
        stair(build, wall + 2, middle - 2, 0, 0, 6, 4);
        slab(build, wall + 8, 1, self.long - 1, self.wide - 1, 6);
        arcade(build, wall + 8, 3, self.wide - 3, 0, 5, 3, True);
        build.pool(wall + 9, 2, -6, self.long - 4, self.wide - 2, 0, 2);
        sump(build, self.long - 7, middle - 1, -11, -6, 2);
        for y in range(middle - 2, middle + 2) {
            build.keep(chapel, wall + 8, y, 6);
        }
        build.way_out(float(self.long) - 3.0, float(middle), 6);
        # Nearing the door wakes the chapel's guard and brings a foe in
        # behind.
        guards = build.waiting();
        near +>:Fires:+> guards;
        near +>:Fires:+> build.summon(2, middle - 1, -10, e2m3_foe(dice, self.danger), 3.5, float(middle) + 0.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e2m3_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, 2.5, 6, e2m3_foe(dice, self.danger, True), 180.0, waits=guards);
        build.foe(float(wall) + 3.5, 2.5, 0, "monster_zombie", 90.0, waits=guards);
        build.foe(3.5, 2.5, 0, "monster_zombie", 90.0, patrol=[[3.5, 2.5], [3.5, float(self.wide) - 2.5]]);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
    }
}

"""e2m3's stretches: [name, role]."""
glob E2M3_STRETCHES: list[list[str]] = [
         ["gate", "start"],
         ["cistern", "flow"],
         ["bridges", "hub"],
         ["bridges", "flow"],
         ["decay", "flow"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e2m3's stretches by its name."""
def make_e2m3(name: str, key: str) -> Prefab {
    if name == "gate" {
        return CryptGate();
    }
    if name == "cistern" {
        return Cistern();
    }
    if name == "bridges" {
        return BridgeHall();
    }
    if name == "decay" {
        return DecayCrypt();
    }
    if name == "vault" {
        return KnightVault(key=key if key else "key_gold");
    }
    return CryptExit(key=key);
}
