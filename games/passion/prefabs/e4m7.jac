"""Prefabs drawn from e4m7, Azure Agony: blue halls drowned in water, a
lagoon under a gallery, rooms joined by a flooded siphon swum under the
hall between, a cistern of galleries and a high bridge over deep water, a
hall where four vores must die before the way on opens, a stair of slow
doors rising out of a pool, the silver key on an island. Raised in e4m7's
own palette.

- `AzureLagoon`: the start. A lagoon in a hall, a walkway round it, a
  gallery along one wall over the walkway and the water's edge, up a lift
  or a stair; rocks standing in the water or a footbridge across it. A
  button deep under the water ("A secret lurks in the hall") opens a
  closet in the hall's corner.
- `DrownedPassage`: three rooms in a row, the middle one's doors shut: the
  first opens when its guards die (a counter of their deaths) or when the
  button over it is shot, the second when shot. Under the middle room a
  siphon runs flooded from a shaft in the first room's floor to one in the
  last's, swum through; some seeds open a well up into the middle room.
- `AzureCistern`: deep water ringed by a ledge, galleries over the ledge
  and the water's edge on two walls up lifts or stairs, a high bridge from
  one across the water to the far wall; ways on from the ledge, the
  galleries and the bridge (a hub). A teleporter at the bottom of the
  water throws a swimmer up onto a secret perch.
- `VoreHall`: a hall, ledges over arcades along its walls, a pool in its
  middle; four guardians (vores, as a run goes deeper) wake on the ledges
  as the player comes in, and only when all four are dead does the way on
  open (e4m7's counter of the four vores). Spawn are teleported in.
- `RisingStair`: a pool across a hall, the way on on a ledge high over the
  water at its far end; a button shot on the ledge's face (or pressed deep
  under the water) raises a stair of slow doors out of the pool to it
  (e4m7's slow rising steps), spikes fly across its top, and what waits on
  the ledge wakes. A gallery over the water from the high ledge.
- `AzureIsle`: the key room. The key on an island in deep water, steps up
  onto it from the water, or a gallery up a stair from the shore whose arm
  ends over the island; taking the key opens the closets on the shore.
- `AzureExit`: the end. A door (a key's, as a gate) into a hall, a pier
  over deep water to the slipgate's alcove; two targets on the far wall,
  shot (a counter), open the alcove, and spikes sweep the pier."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette }
import from .common { stair, key_ambush }
import from .e4m6 { flood, onward_ports, port_door, fired_secret_door, pool_steps }

glob E4M7: str = "q1:e4m7";

"""e4m7's foes: spawn and vores, fiends and hell knights, a shambler
deeper in."""
def e4m7_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_demon1", "monster_hell_knight"] if heavy else ["monster_tarbaby", "monster_zombie", "monster_zombie"], ["monster_shalrath", "monster_shambler"] if heavy else ["monster_hell_knight"], danger * 0.3 if heavy else danger * 0.7));
}

"""A foe whose death counts toward `slain` (a cue its death fires, wired to
a counter), waking with `waits` when given."""
def counted_foe(build: Raising, x: float, y: float, z: int, kind: str, angle: float, slain: Cue, waits: Cue | None = None) {
    if waits is None {
        build.foe(x, y, z, kind, angle, waits=slain);
        return;
    }
    build.foe(x, y, z, kind, angle, waits=waits);
    slain.items.append(waits.items[-1]);
}

"""The start: a lagoon in a hall, a walkway round it, a gallery over its
edge along one wall."""
node AzureLagoon(Prefab) {
    has deep: int = 7,
        gh: int = 8,
        x0: int = 6,
        by_lift: bool = True,
        crossing: int = 0,
        secret_here: bool = True,
        tall: int = 18;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Azure lagoon";
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.deep = dice.between(7, 8);
        self.gh = dice.between(7, 8);
        self.by_lift = dice.chance(0.5);
        self.x0 = 6 if self.by_lift else self.gh + 3;
        self.crossing = dice.below(2);
        self.secret_here = dice.chance(0.7);
        self.long = self.x0 + dice.between(20, 23);
        self.wide = dice.between(20, 24);
        self.tall = self.gh + dice.between(9, 11);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 6), floor=self.gh),
            Port(face=3, along=float(self.long // 2 + 2), floor=0),
            Port(face=0, along=float(self.wide - 4), floor=self.gh)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.gh);
        x0 = self.x0;
        x1 = self.long - 6;
        build.pool(x0, 4, -self.deep, x1, self.wide - 4, 0, 2, False, True, True);
        # The gallery: a slab along the +y wall over the walkway and the
        # water's edge, pillars standing in the water under its lip.
        gy = self.wide - 7;
        bx = (x0 + x1) // 2 - 1;
        build.solid(x0 - 1, gy, self.gh - 1, self.long - 1, self.wide - 1, self.gh);
        for x in range(x0 + 4, x1 - 2, 5) {
            if self.crossing == 0 or x < bx - 1 or x > bx + 3 {
                build.solid(x, gy, -self.deep, x + 1, gy + 1, self.gh - 1);
            }
        }
        if self.by_lift {
            build.put_box({"classname": "func_plat", "height": str(self.gh * 16), "speed": "150"}, float(x0 - 4), float(self.wide - 4), float(self.gh) - 0.5, float(x0 - 1), float(self.wide - 1), float(self.gh), kit_of(build.district).step);
            for y in range(self.wide - 5, self.wide - 1) {
                build.keep(hall, x0 - 5, y, 0);
            }
        } else {
            stair(build, x0 - 1 - self.gh, self.wide - 4, 0, 0, self.gh, 3);
        }
        for y in range(self.wide - 4, self.wide - 1) {
            build.keep(hall, x0 - 1, y, self.gh);
        }
        # Rocks standing in the water, or a footbridge across it.
        if self.crossing == 0 {
            for rock in [[x0 + 5, middle - 2], [x1 - 7, middle]] {
                build.solid(rock[0], rock[1], -self.deep, rock[0] + 2, rock[1] + 2, 1);
            }
        } else {
            build.solid(bx, 4, -1, bx + 3, self.wide - 4, 0);
            for dx in range(3) {
                build.keep(hall, bx + dx, 3, 0);
                build.keep(hall, bx + dx, self.wide - 4, 0);
            }
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The secret: a button deep in the far side of the water opens a
        # closet in the hall's near corner.
        if self.secret_here {
            build.solid(1, 1, 0, 5, 5, 8);
            build.room(1, 1, 0, 4, 3, 5);
            press = build.push(float(x1), float(middle) + 0.5, float(2 - self.deep), 2);
            press.items[0]["message"] = "A secret lurks in the hall";
            press +>:Fires:+> fired_secret_door(build, 1.0, 3.0, 0.0, 4.0, 5.0, 5.0, 3);
            build.secret(1.0, 1.0, 0.0, 4.0, 3.0, 3.0);
            build.supply(2.5, 2.0, 0, "item_artifact_super_damage");
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 2), 6.0, True, "Azure Agony");
        # What lies under the gallery wakes as the player comes to the lift
        # (or the stair).
        climb = build.touch(float(x0 - 5), float(self.wide - 5), 0.0, float(x0), float(self.wide - 1), 6.0);
        under = build.waiting();
        climb +>:Fires:+> under;
        for index in range(dice.between(2, 3)) {
            build.foe(float(x0 + 4 + index * 4) + 0.5, float(self.wide) - 2.5, 0, e4m7_foe(dice, self.danger), 270.0, waits=under);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(x1) + 2.5, 3.5 + float(index) * 5.0, 0, e4m7_foe(dice, self.danger), 180.0);
        }
        build.foe(float(x0) + 1.5, 2.5, 0, "monster_hell_knight" if self.danger > 0.3 else "monster_zombie", 0.0, patrol=[[float(x0) + 1.5, 2.5], [float(x1) - 1.5, 2.5]]);
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.5, self.gh, e4m7_foe(dice, self.danger, True), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 3 + index * 6) + 0.5, float(middle) + 3.5, 1 - self.deep, "monster_fish", 0.0);
        }
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
        build.supply(float(x1) - 2.5, float(self.wide) - 2.5, self.gh, "item_rockets");
    }
}

"""Three rooms in a row, the middle one's doors shut; a flooded siphon
under the middle room from a shaft in the first's floor to one in the
last's."""
node DrownedPassage(Prefab) {
    has near: int = 10,
        mid: int = 10,
        far: int = 10,
        slain_door: bool = True,
        shot_second: bool = True,
        breath: bool = False,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drowned passage";
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.near = dice.between(10, 12);
        self.mid = dice.between(9, 12);
        self.far = dice.between(10, 12);
        self.slain_door = dice.chance(0.6);
        self.shot_second = dice.chance(0.6);
        self.breath = dice.chance(0.5);
        self.long = 1 + self.near + 1 + self.mid + 1 + self.far + 1;
        self.wide = dice.between(16, 18);
        self.tall = dice.between(11, 13);
        self.low = -13;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 5), floor=0), Port(face=3, along=float(self.long - 5), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wa = 1 + self.near;
        wb = wa + 1 + self.mid;
        first = build.room(1, 1, 0, wa, self.wide - 1, self.tall, variant=dice.below(3));
        hall = build.room(wa + 1, 1, 0, wb, self.wide - 1, self.tall, variant=dice.below(3));
        last = build.room(wb + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.widen(first, wa, middle - 2, 0, wa + 1, middle + 2, 8);
        build.widen(hall, wb, middle - 2, 0, wb + 1, middle + 2, 8);
        build.doorway(first, self.enter);
        for port in self.taken {
            build.doorway(last, port);
        }
        # The first door: opened when the room's guards are dead, or when the
        # button over it is shot.
        door_a = build.opened(float(wa), float(middle - 2), 0.0, float(wa + 1), float(middle + 2), 8.0);
        if self.slain_door {
            count = build.tally(2, "The door is open");
            slain = build.cue([], "slain");
            slain +>:Fires:+> count;
            count +>:Fires:+> door_a;
            for index in range(2) {
                counted_foe(build, float(wa) - 3.5, float(middle) + (3.5 if index == 0 else -2.5), 0, e4m7_foe(dice, self.danger, True), 180.0, slain);
            }
            build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 2), 6.0, True, "Its guards hold the door");
        } else {
            shot = build.push(float(wa), float(middle) + 0.5, 9.0, 2, True);
            shot +>:Fires:+> door_a;
            build.foe(float(wa) - 3.5, float(middle) + 3.5, 0, e4m7_foe(dice, self.danger, True), 180.0);
        }
        # The second door: shot open, or opened by a touch.
        if self.shot_second {
            build.rising_door(float(wb), float(middle - 2), 0.0, float(wb + 1), float(middle + 2), 8.0, {"health": "1", "wait": "-1"});
        } else {
            build.rising_door(float(wb), float(middle - 2), 0.0, float(wb + 1), float(middle + 2), 8.0, {"wait": "-1"});
        }
        # The siphon: a shaft in each end room's floor by the -y wall, the
        # flooded tunnel between them under the middle room.
        s1 = 1 + self.near // 2 - 2;
        s2 = wb + 1 + self.far // 2 - 2;
        for sx in [s1, s2] {
            build.room(sx, 1, -12, sx + 4, 5, 0);
            flood(build, sx, 1, -12, sx + 4, 5, -1);
            for x in range(sx - 1, sx + 5) {
                build.keep(first if sx == s1 else last, x, 5, 0);
            }
            for y in range(1, 6) {
                build.keep(first if sx == s1 else last, sx - 1, y, 0);
                build.keep(first if sx == s1 else last, sx + 4, y, 0);
            }
        }
        # The siphon, wide under the middle room, a drowned secret halfway.
        tunnel_y1 = middle - 3;
        build.room(s1, 1, -12, s2 + 4, tunnel_y1, -7);
        flood(build, s1, 1, -12, s2 + 4, tunnel_y1, -7);
        hx = (wa + wb) // 2;
        build.secret(float(hx - 1), 1.0, -12.0, float(hx + 2), float(tunnel_y1), -8.0);
        build.supply(float(hx) + 0.5, 2.5, -12, "item_armor2" if dice.chance(0.4) else "item_health");
        # A well up from the siphon into the middle room, to breathe or to
        # climb out by.
        if self.breath {
            wx = wa + 1 + self.mid // 2 - 1;
            build.room(wx, 1, -7, wx + 3, 4, 0);
            flood(build, wx, 1, -7, wx + 3, 4, -1);
            for x in range(wx - 1, wx + 4) {
                build.keep(hall, x, 4, 0);
            }
            for y in range(1, 5) {
                build.keep(hall, wx - 1, y, 0);
                build.keep(hall, wx + 3, y, 0);
            }
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(wa + 2 + index * 4) + 0.5, 3.0, -11, "monster_fish", 0.0);
        }
        # The middle room's spawn wake as the player comes in.
        into = build.touch(float(wa + 1), float(middle - 3), 0.0, float(wa + 3), float(middle + 3), 6.0);
        stirred = build.waiting();
        into +>:Fires:+> stirred;
        for index in range(dice.between(2, 3)) {
            build.foe(float(wb) - 2.5 - float(index) * 2.0, float(self.wide) - 3.5, 0, e4m7_foe(dice, self.danger), 180.0, waits=stirred);
        }
        build.foe(float(self.long) - 3.5, float(middle) + 4.5, 0, e4m7_foe(dice, self.danger, True), 180.0);
        build.foe(float(wb) + 2.5, float(self.wide) - 2.5, 0, "monster_hell_knight" if self.danger > 0.3 else "monster_demon1", 0.0, patrol=[[float(wb) + 2.5, float(self.wide) - 2.5], [float(self.long) - 2.5, float(self.wide) - 2.5]]);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(s2) + 2.0, 3.0, -12, "item_artifact_super_damage" if dice.chance(0.3) else "item_rockets");
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_spikes");
    }
}

"""Deep water ringed by a ledge, galleries over its edge on two walls, a
high bridge across from one to the far wall."""
node AzureCistern(Prefab) {
    has deep: int = 7,
        gallery: int = 8,
        bridge_here: bool = True,
        by_lift: bool = True,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Azure cistern";
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.long = dice.between(26, 30);
        self.wide = dice.between(24, 26);
        self.deep = dice.between(7, 8);
        self.gallery = dice.between(8, 9);
        self.bridge_here = dice.chance(0.6);
        self.by_lift = dice.chance(0.5);
        self.tall = self.gallery + 11;
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        # The way in at the -x ledge's -y end, clear of the stair along it.
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2), floor=self.gallery if self.bridge_here else 0),
            Port(face=0, along=float(self.wide - 3), floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gallery;
        cistern = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cistern, g);
        build.pool(6, 6, -self.deep, self.long - 6, self.wide - 6, 0, 2, False, True, True);
        stair(build, self.long - 6 - self.deep, 6, -self.deep, 0, self.deep, 2);
        # The galleries, slabs over the ledge to the water's edge.
        build.solid(1, self.wide - 6, g - 1, self.long - 1, self.wide - 1, g);
        build.solid(self.long - 6, 1, g - 1, self.long - 1, self.wide - 6, g);
        step = kit_of(build.district).step;
        # Up to the +y gallery from the -x ledge, a lift or a stair.
        if self.by_lift {
            build.put_box({"classname": "func_plat", "height": str(g * 16), "speed": "200"}, 2.0, float(self.wide - 9), float(g) - 0.5, 5.0, float(self.wide - 6), float(g), step);
        } else {
            stair(build, 2, self.wide - 6 - g, 0, 1, g, 3);
        }
        for x in range(1, 6) {
            build.keep(cistern, x, self.wide - 6, g);
        }
        # Up to the +x gallery from the -y ledge, a lift.
        build.put_box({"classname": "func_plat", "height": str(g * 16), "speed": "200"}, float(self.long - 9), 2.0, float(g) - 0.5, float(self.long - 6), 5.0, float(g), step);
        for y in range(1, 6) {
            build.keep(cistern, self.long - 6, y, g);
        }
        # The high bridge from the +y gallery across the water to the -y
        # wall.
        bx = self.long // 2 - 2;
        if self.bridge_here {
            build.solid(bx, 1, g - 1, bx + 4, self.wide - 6, g);
            for x in range(bx, bx + 4) {
                build.keep(cistern, x, self.wide - 6, g);
            }
        }
        # The secret perch in the -x/-y corner, reached by the teleporter at
        # the bottom of the water; a drop back down.
        build.solid(1, 1, g + 3, 5, 5, g + 4);
        for at in range(1, 5) {
            build.keep(cistern, at, 4, g + 4);
            build.keep(cistern, 4, at, g + 4);
        }
        build.teleporter(float(self.long // 2) + 2.5, float(middle) + 0.5, -self.deep, 2.5, 2.5, g + 4, 45.0);
        build.secret(1.0, 1.0, float(g + 4), 5.0, 5.0, float(g + 7));
        build.supply(2.5, 2.5, g + 4, "item_artifact_super_damage" if dice.chance(0.5) else "item_armor2");
        build.doorway(cistern, self.enter);
        for port in self.taken {
            build.doorway(cistern, port);
        }
        # The galleries' guards wake as the player comes up onto them.
        topped = build.touch(1.0, float(self.wide - 6), float(g), 6.0, float(self.wide - 1), float(g + 6));
        guards = build.waiting();
        topped +>:Fires:+> guards;
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 3.5, g, e4m7_foe(dice, self.danger, True), 270.0, waits=guards);
        build.foe(float(self.long) - 3.5, float(middle) + 0.5, g, e4m7_foe(dice, self.danger), 180.0, waits=guards);
        for index in range(dice.between(2, 3)) {
            build.foe(3.5, 7.5 + float(index) * 3.0, 0, e4m7_foe(dice, self.danger), 0.0);
        }
        build.foe(7.5, 2.5, 0, "monster_hell_knight" if self.danger > 0.3 else "monster_demon1", 0.0, patrol=[[7.5, 2.5], [float(self.long - 11) + 0.5, 2.5]]);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 3.5, 1 - self.deep, "monster_fish", 0.0);
        if self.bridge_here {
            build.foe(float(bx) + 2.0, 3.5, g, e4m7_foe(dice, self.danger), 90.0);
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, g, "item_health");
        build.supply(2.5, float(self.wide) - 12.5, 0, "item_rockets");
    }
}

"""A hall, ledges over arcades along its walls, a pool in its middle; four
guardians on the ledges must die before the way on opens."""
node VoreHall(Prefab) {
    has ledge: int = 9,
        both_ledges: bool = True,
        pool_here: bool = True,
        stairs_up: bool = False,
        bridge_here: bool = True,
        hub: bool = False,
        tall: int = 21;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Vore hall";
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.ledge = dice.between(9, 10);
        self.both_ledges = dice.chance(0.6);
        self.pool_here = dice.chance(0.6);
        # A hub's way on along a ledge wants the stairs up to it.
        self.stairs_up = dice.chance(0.5) or self.hub;
        self.bridge_here = dice.chance(0.65);
        self.long = dice.between(26, 30);
        self.wide = dice.between(20, 24);
        self.tall = self.ledge + dice.between(10, 12);
        self.low = -8;
        self.high = self.tall + 8;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=float(self.long - 5), floor=0),
            Port(face=3, along=float(self.long - 5), floor=0)
        ];
        if self.hub {
            self.leaves.append(Port(face=0, along=float(self.wide - 3), floor=self.ledge));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = 4;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.ledge);
        sides = [0, 1] if self.both_ledges else [1];
        lx0 = 2 + self.ledge if self.stairs_up else 5;
        perches: list[list[float]] = [];
        for side in sides {
            y0 = 1 if side == 0 else self.wide - 1 - g;
            build.solid(lx0, y0, self.ledge - 1, self.long - 1, y0 + g, self.ledge);
            inner = y0 + g - 1 if side == 0 else y0;
            for x in range(lx0 + 2, self.long - 3, 4) {
                build.solid(x, inner, 0, x + 1, inner + 1, self.ledge - 1);
            }
            if self.stairs_up {
                stair(build, 2, y0, 0, 0, self.ledge, g);
                for y in range(y0, y0 + g) {
                    build.keep(hall, lx0, y, self.ledge);
                    build.keep(hall, lx0 - 1, y, self.ledge);
                }
            }
            py = float(y0) + float(g) * 0.5;
            perches.append([float(self.long) - 4.5, py]);
            perches.append([float(lx0 + (self.long - lx0) // 2) + 0.5, py]);
        }
        if len(sides) == 2 and self.bridge_here {
            # A bridge between the ledges across the hall's middle.
            bx = self.long // 2 - 2;
            build.solid(bx, 1 + g, self.ledge - 1, bx + 4, self.wide - 1 - g, self.ledge);
            for x in range(bx, bx + 4) {
                build.keep(hall, x, g, self.ledge);
                build.keep(hall, x, self.wide - 1 - g, self.ledge);
            }
        }
        if len(sides) == 1 {
            # With one ledge, a balcony across the far end holds the others.
            build.solid(self.long - 5, 1, self.ledge - 1, self.long - 1, self.wide - 1 - g, self.ledge);
            perches.append([float(self.long) - 3.0, 3.5]);
            perches.append([float(self.long) - 3.0, float(middle) - 1.5]);
        }
        if self.pool_here {
            depth = 6;
            build.pool(8, g + 3, -depth, self.long - 8, self.wide - g - 3, 0, 2, False, False);
            pool_steps(build, 8, g + 3, depth, 2);
            pool_steps(build, 8, self.wide - g - 5, depth, 2);
            build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 1 - depth, "monster_fish", 0.0);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The four guardians wake as the player comes in; their deaths
        # together open the ways on.
        into = build.touch(1.0, float(middle - 3), 0.0, 5.0, float(middle + 3), 6.0);
        roused = build.waiting();
        into +>:Fires:+> roused;
        count = build.tally(4, "The way on is open");
        slain = build.cue([], "slain");
        slain +>:Fires:+> count;
        for (index, at) in enumerate(perches[:4]) {
            kind = "monster_shalrath" if self.danger > 0.25 else ("monster_hell_knight" if index % 2 == 0 else "monster_demon1");
            counted_foe(build, at[0], at[1], self.ledge, kind, 180.0, slain, roused);
        }
        for port in onward_ports(self) {
            count +>:Fires:+> port_door(build, self, port);
        }
        # Spawn brought in behind the player as the guardians wake.
        for index in range(1 + (1 if self.danger > 0.4 else 0)) {
            into +>:Fires:+> build.summon(3 + index * 4, 1, self.tall + 1, "monster_tarbaby", 6.5 + float(index) * 2.0, float(middle) + 0.5, 0, 0.0);
        }
        build.foe(float(self.long) - 6.5, float(middle) + 0.5, 0, "monster_hell_knight" if self.danger > 0.3 else "monster_zombie", 90.0, patrol=[[float(self.long) - 6.5, float(g) + 2.5], [float(self.long) - 6.5, float(self.wide - g) - 2.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_rockets");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_health");
    }
}

"""A pool across a hall, the way on on a high ledge at its far end; a
button raises a stair of slow doors out of the water to it."""
node RisingStair(Prefab) {
    has near: int = 6,
        deep: int = 7,
        up: int = 7,
        lane: int = 5,
        shot_button: bool = True,
        alcove_here: bool = True,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Rising stair";
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.near = dice.between(5, 7);
        self.deep = dice.between(6, 8);
        self.up = dice.between(6, 8);
        self.shot_button = dice.chance(0.6);
        self.alcove_here = dice.chance(0.6);
        self.wide = dice.between(16, 20);
        self.lane = dice.between(4, self.wide - 9);
        count = self.up + 3;
        self.long = 1 + self.near + count + dice.between(4, 6) + 6 + 1;
        self.tall = self.up + dice.between(10, 12);
        self.low = -self.up - 8;
        self.high = self.tall + 1;
        fx = self.long - 7;
        self.enter = Port(face=2, along=float(dice.between(4, self.wide - 4)), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide // 2), floor=self.up),
            Port(face=1, along=float(fx + 3), floor=self.up),
            Port(face=3, along=float(fx + 3), floor=self.up)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.up);
        fx = self.long - 7;
        x0 = 1 + self.near;
        build.pool(x0, 1, -self.deep, fx, self.wide - 1, 0, 2, False, True, True);
        build.solid(fx, 1, -self.deep, self.long - 1, self.wide - 1, self.up);
        # The stair of doors from three lifts under the water up to the
        # ledge, slow to rise.
        count = self.up + 3;
        sx = fx - count;
        steps = build.rising_steps(sx, self.lane, -3, 0, count, 4);
        for item in steps.items {
            item["speed"] = str(18 + dice.below(10));
        }
        for y in range(self.lane, self.lane + 4) {
            build.keep(hall, fx, y, self.up);
        }
        # The button: shot on the ledge's face over the water, or pressed
        # deep under it.
        button_y = self.lane + 6 if self.lane + 7 < self.wide - 1 else self.lane - 2;
        button = build.push(float(fx), float(button_y) + 0.5, 2.0 if self.shot_button else float(2 - self.deep), 2, self.shot_button);
        button +>:Fires:+> steps;
        build.touch(1.0, 1.0, 0.0, float(x0), float(self.wide - 1), 6.0, True, "Shoot the button on the far ledge" if self.shot_button else "A button lies deep under the water");
        # Spikes across the stair's top while anyone climbs it.
        climbing = build.touch(float(fx - 4), float(self.lane), float(self.up - 4), float(fx), float(self.lane + 4), float(self.up + 4), False);
        climbing +>:Fires:+> build.spikes(float(fx) - 2.0, float(self.wide - 1) - 0.1, float(self.up) + 1.5, 3);
        # The gallery back over the water from the high ledge, along the +y
        # wall.
        if self.lane + 4 < self.wide - 5 {
            build.solid(x0, self.wide - 5, self.up - 1, fx, self.wide - 1, self.up);
            build.foe(float(x0) + 2.5, float(self.wide) - 3.0, self.up, e4m7_foe(dice, self.danger, True), 0.0);
            build.supply(float(x0) + 1.5, float(self.wide) - 2.0, self.up, "item_armor2" if dice.chance(0.3) else "item_rockets");
            for y in range(self.wide - 5, self.wide - 1) {
                build.keep(hall, x0, y, self.up);
            }
        }
        # A drowned alcove in the high ledge's face, beyond the button.
        if self.alcove_here {
            ay = 1 if abs(button_y - 1) > abs(button_y - (self.wide - 4)) else self.wide - 4;
            build.room(fx, ay, -self.deep, fx + 3, ay + 3, 3 - self.deep);
            flood(build, fx, ay, -self.deep, fx + 3, ay + 3, 3 - self.deep);
            build.secret(float(fx), float(ay), float(-self.deep), float(fx + 3), float(ay + 3), float(3 - self.deep));
            build.supply(float(fx) + 2.0, float(ay) + 1.5, -self.deep, "item_artifact_super_damage");
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The ledge's guards wake as the stair rises.
        guards = build.waiting();
        button +>:Fires:+> guards;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, 2.5 + float(index) * 4.0, self.up, e4m7_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 3 + index * 4) + 0.5, float(middle) + 0.5, 1 - self.deep, "monster_fish", 0.0);
        }
        build.foe(2.5, 2.5, 0, "monster_hell_knight" if self.danger > 0.3 else "monster_zombie", 90.0, patrol=[[2.5, 2.5], [2.5, float(self.wide) - 2.5]]);
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.up, "item_health");
    }
}

"""The key on an island in deep water, steps up onto it, or a gallery
whose arm ends over it; taking it opens the closets on the shore."""
node AzureIsle(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        deep: int = 6,
        gh: int = 7,
        gallery_here: bool = True,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Azure isle (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(6, 7);
        self.gh = dice.between(6, 7);
        self.gallery_here = dice.chance(0.8);
        self.tall = self.gh + dice.between(8, 9);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2 + 1;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, self.gh);
        build.doorway(hall, self.enter);
        x0 = 6;
        build.pool(x0, 1, -self.deep, self.long - 1, side, 0, 2);
        ix = self.long - 6;
        build.solid(ix - 2, cy - 2, -self.deep, ix + 2, cy + 2, 0);
        stair(build, ix - 2 - self.deep, cy - 1, -self.deep, 0, self.deep, 2);
        # The gallery: up a stair from the shore along the -y wall, out over
        # the water, its arm ending over the island to drop onto it.
        if self.gallery_here {
            stair(build, 1, 1, 0, 0, self.gh, 3);
            build.solid(1 + self.gh, 1, self.gh - 1, ix + 2, 4, self.gh);
            build.solid(ix - 2, 4, self.gh - 1, ix + 2, cy - 1, self.gh);
            for x in range(ix - 2, ix + 2) {
                build.keep(hall, x, cy - 2, self.gh);
            }
            build.foe(float(ix) - 6.5, 2.5, self.gh, e4m7_foe(dice, self.danger), 0.0);
            build.supply(float(ix) + 0.5, 2.5, self.gh, "item_rockets");
        }
        key_ambush(build, self.key, float(ix), float(cy), 0, side, 0, [1], [e4m7_foe(dice, self.danger, True)]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(x0 + 3 + index * 4) + 0.5, float(cy) + 3.5, 1 - self.deep, "monster_fish", 0.0);
        }
        build.foe(3.0, float(side) - 2.5, 0, e4m7_foe(dice, self.danger), 0.0);
        build.supply(2.5, float(side) - 4.5, 0, "item_health");
    }
}

"""The end: a door into a hall, a pier over deep water to the slipgate's
alcove, opened by shooting the targets on the far wall."""
node AzureExit(Prefab) {
    has key: str = "",
        targets: bool = True,
        spiked: bool = True,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Azure exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E4M7;
        self.district = level_district(E4M7);
        self.long = dice.between(28, 30);
        self.wide = dice.between(16, 18);
        self.tall = dice.between(13, 15);
        self.targets = dice.chance(0.65);
        self.spiked = dice.chance(0.5);
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
        wall = 8;
        alcove_x = self.long - 6;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        room = build.room(wall + 1, 1, 0, alcove_x, self.wide - 1, self.tall, variant=dice.below(3));
        alcove = build.room(alcove_x + 1, middle - 3, 0, self.long - 1, middle + 3, 9, variant=dice.below(3));
        build.doorway(hall, self.enter);
        build.widen(room, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        x0 = wall + 3;
        build.pool(x0, 1, -7, alcove_x, self.wide - 1, 0, 2, False, False);
        pool_steps(build, x0, 1, 7, 2);
        pool_steps(build, x0, self.wide - 3, 7, 2);
        build.solid(x0, middle - 2, -1, alcove_x, middle + 1, 0);
        for x in range(x0 + 3, alcove_x - 1, 4) {
            build.solid(x, middle - 2, -7, x + 1, middle - 1, -1);
            build.solid(x, middle, -7, x + 1, middle + 1, -1);
        }
        for y in range(middle - 2, middle + 1) {
            build.keep(room, x0 - 1, y, 0);
        }
        build.widen(alcove, alcove_x, middle - 2, 0, alcove_x + 1, middle + 1, 8);
        build.way_out(float(self.long) - 3.0, float(middle), 0);
        # The alcove's door: opened by the two targets on the far wall, shot,
        # or by a touch.
        if self.targets {
            door = build.opened(float(alcove_x), float(middle - 2), 0.0, float(alcove_x + 1), float(middle + 1), 8.0);
            count = build.tally(2, "The way out is open");
            count +>:Fires:+> door;
            for y in [3, self.wide - 4] {
                build.push(float(alcove_x), float(y) + 0.5, 5.0, 2, True) +>:Fires:+> count;
            }
            build.touch(float(wall + 1), 1.0, 0.0, float(x0), float(self.wide - 1), 6.0, True, "Shoot the targets on the far wall");
        } else {
            build.rising_door(float(alcove_x), float(middle - 2), 0.0, float(alcove_x + 1), float(middle + 1), 8.0, {"wait": "-1"});
        }
        # Spikes sweep the pier while anyone is on it.
        if self.spiked {
            on_pier = build.touch(float(x0 + 2), float(middle - 2), 0.0, float(alcove_x - 2), float(middle + 1), 6.0, False);
            on_pier +>:Fires:+> build.spikes(float(x0 + 4), float(self.wide - 1) - 0.1, 1.5, 3);
            on_pier +>:Fires:+> build.spikes(float(alcove_x - 4), 1.1, 1.5, 1);
        }
        # Reaching the alcove brings a hell knight in behind.
        into = build.touch(float(alcove_x + 1), float(middle - 3), 0.0, float(alcove_x + 3), float(middle + 3), 6.0);
        into +>:Fires:+> build.summon(alcove_x + 1, 1, self.tall + 1, "monster_hell_knight", float(x0) + 2.5, float(middle) - 0.5, 0, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, e4m7_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(x0) + 3.5, 3.5, -6, "monster_fish", 0.0);
        build.foe(float(wall) + 1.5, 2.5, 0, "monster_zombie", 90.0, patrol=[[float(wall) + 1.5, 2.5], [float(wall) + 1.5, float(self.wide) - 2.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e4m7's stretches: [name, role]."""
glob E4M7_STRETCHES: list[list[str]] = [
         ["lagoon", "start"],
         ["drowned", "flow"],
         ["cistern", "hub"],
         ["cistern", "flow"],
         ["vores", "flow"],
         ["vores_hub", "hub"],
         ["stair", "flow"],
         ["isle", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e4m7's stretches by its name."""
def make_e4m7(name: str, key: str) -> Prefab {
    if name == "lagoon" {
        return AzureLagoon();
    }
    if name == "drowned" {
        return DrownedPassage();
    }
    if name == "cistern" {
        return AzureCistern();
    }
    if name == "vores" {
        return VoreHall();
    }
    if name == "vores_hub" {
        return VoreHall(hub=True);
    }
    if name == "stair" {
        return RisingStair();
    }
    if name == "isle" {
        return AzureIsle(key=key if key else "key_silver");
    }
    return AzureExit(key=key);
}
