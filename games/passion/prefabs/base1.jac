"""Prefabs drawn from Quake II's base1, the Outer Base: a canyon under the
sky outside the base, a bridge over the stream at its bottom, a yard
round a control tower with walkways out of it high up, a security room
up a lift, the way out on a landing pad. Raised in base1's own palette.

- `CanyonGate`: the start. A canyon, rock along its walls, the base's
  bunker across its far end and its door; ways on from the bunker and
  the canyon's sides. The help computer gives the first objective; a
  broken panel sparks by the bunker (base1's timed sparks); guards appear
  in the bunker as the player climbs its steps (TRIGGER_SPAWN); a panel
  in the canyon's wall breaks open on a stash when shot (a secret).
- `CanyonBridge`: a gorge, a stream far down at its bottom, a metal bridge
  over it; a stair up the gorge's wall for whoever falls. Halfway over,
  charges go off along the bridge and guards appear on the far side.
- `ControlYard`: a yard round a control tower, a ramp up to its top and
  walkways from it to ways on high in two walls; ways on below too (a
  hub). Its panels spark, a guard walks round the tower, guards appear on
  the walkways as the player comes up the ramp, and the objective moves on.
- `SecurityRoom`: the key on a control deck up a lift; taking it opens
  the closets; the consoles spark.
- `LandingPad`: the end. A door (a key's, as a gate) out to a pad under
  the sky, the way out on it; guards appear in the yard as the player comes
  out, and the pad's charges go off as the player climbs onto it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q2_foe, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, boulders, key_ambush }

glob BASE1: str = "q2:base1";

"""The start: a canyon, rock along its walls, the bunker across its end."""
node CanyonGate(Prefab) {
    has bunker: int = 4,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Canyon gate";
        self.source = BASE1;
        self.district = level_district(BASE1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(20, 24);
        self.bunker = dice.between(3, 4);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=self.bunker), Port(face=1, along=float(self.long // 2), floor=0), Port(face=3, along=float(self.long // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        canyon = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(canyon, self.bunker);
        bx = self.long - 7;
        build.solid(bx, 1, 0, self.long - 1, self.wide - 1, 10);
        build.widen(canyon, bx, middle - 2, self.bunker, self.long - 1, middle + 2, self.bunker + 8);
        build.solid(bx - 4, middle - 3, 0, bx, middle + 3, self.bunker);
        stair(build, bx - 4 - self.bunker, middle - 2, 0, 0, self.bunker, 4);
        for y in range(middle - 2, middle + 2) {
            build.keep(canyon, bx - 4, y, self.bunker);
        }
        clear = [[0, middle - 3, 5, middle + 3], [bx - 9, middle - 4, bx, middle + 4], [self.long // 2 - 3, 0, self.long // 2 + 3, 5], [self.long // 2 - 3, self.wide - 5, self.long // 2 + 3, self.wide], [7, 0, 13, 6]];
        # The stash: a closet in an outcrop of the canyon's wall, behind a
        # panel that breaks when shot.
        build.solid(8, 1, 0, 12, 4, 8);
        build.room(9, 1, 0, 11, 3, 4);
        build.breakable(9.0, 3.0, 0.0, 11.0, 4.0, 4.0, 20);
        build.secret(9.0, 1.0, 0.0, 11.0, 3.0, 3.0);
        build.supply(10.0, 2.0, 0, Q2_ARMOR, "q2");
        boulders(build, dice, 1, 1, bx, self.wide - 1, 0, dice.between(6, 9), clear);
        build.doorway(canyon, self.enter);
        for port in self.taken {
            build.doorway(canyon, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 5.0, float(self.wide - 1), 8.0) +>:Fires:+> build.objective("Locate the base installation and get inside");
        # A broken panel by the bunker's mouth, sparking now and then.
        build.timer(4.0) +>:Fires:+> build.sparks(float(bx) - 0.2, float(middle) + 3.5, 3.0, 2);
        # Guards appear in the bunker as the player climbs its steps.
        climb = build.touch(float(bx - 4), float(middle - 2), float(self.bunker), float(bx), float(middle + 2), float(self.bunker + 6));
        guards = build.waiting();
        climb +>:Fires:+> guards;
        for index in range(dice.between(1, 2)) {
            build.foe(float(bx) + 2.5 + float(index) * 2.0, float(middle) + (1.0 if index % 2 == 0 else -1.0), self.bunker, q2_foe(dice, self.danger), 180.0, waits=guards);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(self.long // 2 + index % 2 * 3) + 0.5, 3.5 + float(index) * 4.0, 0, q2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(bx) - 2.0, float(middle) + 0.5, self.bunker, q2_foe(dice, self.danger, True), 180.0);
        build.supply(float(bx) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A gorge, a stream far down at its bottom, a metal bridge over it; a
stair up the gorge's wall."""
node CanyonBridge(Prefab) {
    has deep: int = 9,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Canyon bridge";
        self.source = BASE1;
        self.district = level_district(BASE1);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.deep = dice.between(8, 10);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 3;
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
        low = -self.deep;
        gorge = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(gorge, 0);
        x0 = 6;
        x1 = self.long - 6;
        build.solid(1, 1, low, x0, self.wide - 1, 0);
        build.solid(x1, 1, low, self.long - 1, self.wide - 1, 0);
        # The stream down the gorge's middle, the bridge over it all.
        build.pool(x0 + self.deep + 1, 1, low - 2, x1, self.wide - 1, low, 2);
        build.solid(x0, middle - 2, -1, x1, middle + 2, 0);
        stair(build, x0 + self.deep - 1, 1, low, 2, self.deep, 2);
        for y in range(middle - 2, middle + 2) {
            build.keep(gorge, x0 - 1, y, 0);
            build.keep(gorge, x1, y, 0);
        }
        build.doorway(gorge, self.enter);
        for port in self.taken {
            build.doorway(gorge, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 2.5, 2.5 + float(index) * 4.0, 0, q2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 4.5, 4, q2_foe(dice, self.danger, False, True), 180.0);
        # Halfway over, charges go off along the bridge, one after another,
        # and guards appear on the far side.
        halfway = build.touch(float(self.long // 2 - 1), float(middle - 2), 0.0, float(self.long // 2 + 1), float(middle + 2), 6.0);
        for index in range(3) {
            late = build.delay(0.3 * float(index));
            halfway +>:Fires:+> late;
            late +>:Fires:+> build.explosion(float(self.long // 2 - 3 + index * 3) + 0.5, float(middle - 3) + (0.0 if index % 2 == 0 else 6.0), -2.0);
        }
        far_side = build.waiting();
        halfway +>:Fires:+> far_side;
        for index in range(dice.between(1, 2)) {
            build.foe(float(x1) + 3.5, float(middle) + 2.5 - float(index) * 5.0, 0, q2_foe(dice, self.danger), 180.0, waits=far_side);
        }
        build.foe(float(x0 + self.deep + 3) + 0.5, 3.5, low, q2_foe(dice, self.danger), 90.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(x0) + 2.5, float(self.wide) - 2.5, low, "ammo_bullets", "q2");
    }
}

"""A yard round a control tower, a ramp up to its top and walkways from it
to ways on high in two walls."""
node ControlYard(Prefab) {
    has tower: int = 7,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Control yard";
        self.source = BASE1;
        self.district = level_district(BASE1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.tower = dice.between(7, 8);
        self.tall = self.tower + 13;
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.tower),
            Port(face=0, along=middle, floor=self.tower),
            Port(face=3, along=float(self.long // 2) + 5.0, floor=0),
            Port(face=1, along=5.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.tower);
        tx0 = cx - 4;
        tx1 = cx + 4;
        ty0 = cy - 4;
        ty1 = cy + 4;
        build.solid(tx0, ty0, 0, tx1, ty1, self.tower);
        # The ramp up the tower's south face, climbing east.
        stair(build, tx0 - 2, ty0 - 3, 0, 0, self.tower, 3);
        for x in range(tx0 + self.tower - 4, tx0 + self.tower - 1) {
            build.keep(yard, x, ty0, self.tower);
        }
        # The walkways: north to the wall, east to the wall.
        build.solid(cx - 2, ty1, self.tower - 1, cx + 2, self.wide - 1, self.tower);
        build.solid(tx1, cy - 2, self.tower - 1, self.long - 1, cy + 2, self.tower);
        for at in range(-2, 2) {
            build.keep(yard, cx + at, ty1 - 1, self.tower);
            build.keep(yard, tx1 - 1, cy + at, self.tower);
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 5) + 0.5, 3.5 + float(index % 2) * (float(self.wide) - 7.0), 0, q2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.tower, q2_foe(dice, self.danger, True), 180.0);
        # The tower's panels spark; a guard walks round it.
        build.timer(3.0) +>:Fires:+> build.sparks(float(tx1) + 0.2, float(ty0) + 1.5, 3.0, 0);
        build.timer(5.0) +>:Fires:+> build.sparks(float(tx0) + 1.5, float(ty1) + 0.2, 3.0, 1);
        build.foe(float(tx0) - 1.5, float(ty1) + 1.5, 0, "monster_soldier", 0.0, patrol=[[float(tx0) - 1.5, float(ty1) + 1.5], [float(tx1) + 1.5, float(ty1) + 1.5], [float(tx1) + 1.5, float(ty0) - 4.5], [float(tx0) - 3.5, float(ty0) - 4.5]]);
        # Coming in, the objective moves on; at the ramp's top, guards appear
        # on the walkways.
        build.touch(1.0, float(cy - 3), 0.0, 4.0, float(cy + 3), 8.0) +>:Fires:+> build.objective("Find the security pass for the base's inner door");
        ramp_top = build.touch(float(tx0 + self.tower - 4), float(ty0), float(self.tower), float(tx0 + self.tower), float(ty0 + 3), float(self.tower + 6));
        walkway = build.waiting();
        ramp_top +>:Fires:+> walkway;
        build.foe(float(cx) + 0.5, float(self.wide) - 3.5, self.tower, q2_foe(dice, self.danger), 270.0, waits=walkway);
        build.foe(float(self.long) - 3.5, float(cy) + 0.5, self.tower, q2_foe(dice, self.danger), 180.0, waits=walkway);
        build.foe(float(cx) + 6.5, float(cy) + 6.5, 10, q2_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(cx) - 2.5, float(cy) + 2.5, self.tower, Q2_ARMOR, "q2");
        build.supply(float(self.long) - 3.5, 3.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key on a control deck up a lift; taking it opens the closets."""
node SecurityRoom(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        deck: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Security room (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BASE1;
        self.district = level_district(BASE1);
        self.long = dice.between(18, 20);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.deck = dice.between(5, 7);
        self.tall = self.deck + 8;
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
        room = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(room, self.deck);
        build.doorway(room, self.enter);
        dx = self.long - 6;
        build.solid(dx, 2, 0, self.long - 1, side - 1, self.deck);
        build.put_box({"classname": "func_plat", "height": str(self.deck * 16), "speed": "200"}, float(dx - 3), float(cy - 1), float(self.deck) - 0.5, float(dx), float(cy + 2), float(self.deck), kit_of(build.district).step);
        for y in range(cy - 2, cy + 3) {
            build.keep(room, dx, y, self.deck);
        }
        # Consoles along the deck's back wall.
        build.solid(self.long - 2, 3, self.deck, self.long - 1, side - 2, self.deck + 2);
        key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, self.deck, side, 0, [2, dx - 6], [q2_foe(dice, self.danger, True), q2_foe(dice, self.danger)]);
        build.foe(float(self.long) - 3.5, 3.5, self.deck, q2_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.timer(6.0) +>:Fires:+> build.sparks(float(self.long) - 2.2, float(cy) - 3.5, float(self.deck) + 1.5, 2);
    }
}

"""The end: a door out to a pad under the sky, the way out on it."""
node LandingPad(Prefab) {
    has key: str = "",
        pad: int = 2,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Landing pad" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = BASE1;
        self.district = level_district(BASE1);
        self.long = dice.between(24, 26);
        self.wide = dice.between(18, 20);
        self.pad = dice.between(1, 2);
        self.tall = dice.between(18, 22);
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
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        yard = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.pad);
        build.doorway(hall, self.enter);
        build.widen(yard, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            build.rising_door(float(wall), float(middle - 2), 0.0, float(wall + 1), float(middle + 2), 8.0, {"key": self.key, "wait": "-1"});
        }
        px = self.long - 10;
        build.solid(px, middle - 5, 0, self.long - 2, middle + 5, self.pad);
        stair(build, px - self.pad, middle - 2, 0, 0, self.pad, 4);
        build.way_out(float(px) + 4.0, float(middle), self.pad);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, q2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, 2.5, 0, q2_foe(dice, self.danger, True), 180.0);
        build.foe(float(px) + 2.5, float(middle) + 6.5, 6, q2_foe(dice, self.danger, False, True), 180.0);
        # Out in the yard, guards appear; on the pad, its charges go off.
        out_touch = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        yard_guard = build.waiting();
        out_touch +>:Fires:+> yard_guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(px) - 3.5, 2.5 + float(index) * (float(self.wide) - 5.0), 0, q2_foe(dice, self.danger), 0.0, waits=yard_guard);
        }
        on_pad = build.touch(float(px), float(middle - 5), float(self.pad), float(px + 2), float(middle + 5), float(self.pad + 6));
        on_pad +>:Fires:+> build.explosion(float(self.long) - 2.5, float(middle - 6) + 0.5, 3.0);
        on_pad +>:Fires:+> build.explosion(float(self.long) - 2.5, float(middle + 6) + 0.5, 3.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""base1's stretches: [name, role]."""
glob BASE1_STRETCHES: list[list[str]] = [
         ["canyon", "start"],
         ["bridge", "flow"],
         ["yard", "hub"],
         ["yard", "flow"],
         ["security", "keyroom"],
         ["pad", "end"],
         ["pad", "gate"]
     ];

"""One of base1's stretches by its name."""
def make_base1(name: str, key: str) -> Prefab {
    if name == "canyon" {
        return CanyonGate();
    }
    if name == "bridge" {
        return CanyonBridge();
    }
    if name == "yard" {
        return ControlYard();
    }
    if name == "security" {
        return SecurityRoom(key=key if key else "key_silver");
    }
    return LandingPad(key=key);
}
