"""Prefabs drawn from Quake II's base1, the Outer Base: a canyon under the
sky outside the base, a bridge over the stream at its bottom, a yard
round a control tower with walkways out of it high up, the base's
elevator, its communication centre, a security room up a lift, the way
out on a landing pad. Its panels spark on timers everywhere (base1's
func_timers and relays), charges go off, guards appear (TRIGGER_SPAWN).
Raised in base1's own palette.

- `CanyonGate`: the start. A canyon, rock along its walls, the base's
  bunker across its far end and its door; ways on from the bunker and
  the canyon's sides. The help computer gives the first objective; broken
  panels spark by the bunker; guards appear in the bunker as the player
  climbs its steps; a panel in the canyon's wall breaks open on a stash
  when shot (a secret); by the dice a natural arch spans the canyon, a
  guard on it, a ramp up to it.
- `CanyonBridge`: a gorge, a stream (or a channel of slime) far down at
  its bottom, a metal bridge over it, now and then a spur off it to a
  lookout; a stair up the gorge's wall for whoever falls. Halfway over,
  charges go off along the bridge and guards appear on the far side.
- `ControlYard`: a yard round a control tower, a ramp up to its top and
  walkways from it to ways on high in two walls; ways on below too (a
  hub). The tower may be hollow, a control room in its foot whose console
  establishes the communication link (base1's objective), charges and
  guards answering; a cargo lift may ride its side; panels spark, guards
  walk round it.
- `BaseElevator`: the base's elevator (base1's "Locate base installation
  elevator"): a landing over a shaft room, the elevator riding between
  them (running, or called by a button), a stair down the wall beside it;
  gone down or come up by the dice; guards appear as it arrives.
- `CommCenter`: a two-floor control room, a gallery round its walls up
  two stairs, consoles in the middle; the console on the gallery sends
  the message (the objective moves on), charges go off and guards appear
  on the floor below; ways on from both floors.
- `SecurityRoom`: the key on a control deck up a lift or a stair; taking
  it opens the closets and moves the objective on; the consoles spark; a
  vent panel breaks open on a stash.
- `LandingPad`: the end. A door (a key's, as a gate) out to a pad under
  the sky, the way out on it, low up a few steps or high on a tower up a
  lift; guards appear in the yard as the player comes out, and the pad's
  charges go off as the player climbs onto it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q2_foe, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, boulders, key_ambush, key_item, lift, pillars }
import from .e1m1_parts { deck, stash, bars }

glob BASE1: str = "q2:base1";

"""A broken panel at (x, y), `z` lifts up, sparking out the way `direction`
goes every `every` seconds (base1's func_timer), a relay a tenth of a
second on throwing a second burst (its paired relays). Answers the
timer's cue."""
def sparking(build: Raising, x: float, y: float, z: float, direction: int, every: float) -> Cue {
    clock = build.timer(every);
    clock +>:Fires:+> build.sparks(x, y, z, direction);
    again = build.delay(0.1);
    clock +>:Fires:+> again;
    again +>:Fires:+> build.sparks(x, y, z + 0.5, direction);
    return clock;
}

"""Charges going off one after another at `points` ([x, y, z] each), a
`gap` of seconds between them, when `cue` fires."""
def charges(build: Raising, cue: Cue, points: list[list[float]], gap: float) {
    for (index, point) in enumerate(points) {
        late = build.delay(gap * float(index) + 0.1);
        cue +>:Fires:+> late;
        late +>:Fires:+> build.explosion(point[0], point[1], point[2]);
    }
}

"""What a secret of base1's holds."""
def base1_reward(dice: Stream) -> str {
    return ["item_armor_combat", "item_quad", "item_adrenaline", "weapon_chaingun"][dice.below(4)];
}

"""The start: a canyon, rock along its walls, the bunker across its end."""
node CanyonGate(Prefab) {
    has bunker: int = 4,
        tall: int = 22,
        arch: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Canyon gate";
        self.source = BASE1;
        self.district = level_district(BASE1);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 22);
        self.tall = dice.between(20, 24);
        self.bunker = dice.between(3, 4);
        self.arch = dice.chance(0.55);
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
        # The natural arch across the canyon, and the ramp up to it along
        # the far wall.
        if self.arch {
            ax = 5;
            build.level(canyon, 7);
            deck(build, ax, 1, ax + 3, self.wide - 1, 7);
            stair(build, ax + 9, self.wide - 7, 0, 2, 7, 3);
            for y in range(self.wide - 7, self.wide - 4) {
                build.keep(canyon, ax + 2, y, 7);
            }
            clear.append([ax - 1, 0, ax + 4, self.wide]);
            clear.append([ax + 2, self.wide - 9, ax + 11, self.wide - 3]);
            build.supply(float(ax) + 1.5, float(middle) + 0.5, 7, Q2_AMMO[dice.below(len(Q2_AMMO))], "q2");
            build.supply(float(ax) + 1.5, float(middle) - 2.5, 7, Q2_HEALTH, "q2");
        }
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
        # Broken panels by the bunker's mouth, sparking now and then.
        sparking(build, float(bx) - 0.2, float(middle) + 3.5, 3.0, 2, 4.0);
        sparking(build, float(bx) - 0.2, float(middle) - 3.5, 2.0, 2, 6.0);
        # Guards appear in the bunker as the player climbs its steps.
        climb = build.touch(float(bx - 4), float(middle - 2), float(self.bunker), float(bx), float(middle + 2), float(self.bunker + 6));
        guards = build.waiting();
        climb +>:Fires:+> guards;
        for index in range(dice.between(1, 2)) {
            build.foe(float(bx) + 2.5 + float(index) * 2.0, float(middle) + (1.0 if index % 2 == 0 else -1.0), self.bunker, q2_foe(dice, self.danger), 180.0, waits=guards);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 + index % 2 * 3) + 0.5, 3.5 + float(index) * 4.0, 0, q2_foe(dice, self.danger), 180.0);
        }
        build.foe(float(bx) - 2.0, float(middle) + 0.5, self.bunker, q2_foe(dice, self.danger, True), 180.0);
        # A guard walking the canyon's floor.
        build.foe(14.5, float(self.wide) - 3.5, 0, "monster_soldier_light", 0.0, patrol=[[14.5, float(self.wide) - 3.5], [float(bx) - 6.5, float(self.wide) - 3.5]]);
        build.supply(float(bx) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(4.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(2.5, float(middle) + 2.5, 0, Q2_ARMOR, "q2");
        build.supply(float(bx) - 6.5, float(middle) + 3.5, 0, Q2_HEALTH, "q2");
    }
}

"""A gorge, a stream far down at its bottom, a metal bridge over it (and a
spur off it to a lookout); a stair up the gorge's wall."""
node CanyonBridge(Prefab) {
    has deep: int = 9,
        tall: int = 14,
        spur: bool = False,
        slime: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Canyon bridge";
        self.source = BASE1;
        self.district = level_district(BASE1);
        self.long = dice.between(26, 28);
        self.spur = dice.chance(0.5);
        self.slime = dice.chance(0.35);
        self.wide = dice.between(18, 20) if self.spur else dice.between(16, 18);
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
        # The stream (or slime) down the gorge's middle, the bridge over it
        # all, and the stair up the near wall.
        build.pool(x0 + self.deep + 1, 1, low - 2, x1, self.wide - 1, low, 3 if self.slime else 2);
        build.solid(x0, middle - 2, -1, x1, middle + 2, 0);
        stair(build, x0 + self.deep - 1, 1, low, 2, self.deep, 3);
        for y in range(middle - 2, middle + 2) {
            build.keep(gorge, x0 - 1, y, 0);
            build.keep(gorge, x1, y, 0);
        }
        # The spur off the bridge's middle to a lookout against the far wall.
        cx = self.long // 2;
        if self.spur {
            build.solid(cx - 1, middle + 2, -1, cx + 2, self.wide - 4, 0);
            build.solid(cx - 3, self.wide - 4, -1, cx + 4, self.wide - 1, 0);
            for x in range(cx - 1, cx + 2) {
                build.keep(gorge, x, middle + 1, 0);
            }
            build.foe(float(cx) + 0.5, float(self.wide) - 2.5, 0, q2_foe(dice, self.danger), 270.0);
            build.supply(float(cx) - 2.0, float(self.wide) - 2.0, 0, Q2_AMMO[dice.below(len(Q2_AMMO))], "q2");
            sparking(build, float(cx) + 0.5, float(self.wide - 1) - 0.2, 2.5, 3, 5.0);
        }
        build.doorway(gorge, self.enter);
        for port in self.taken {
            build.doorway(gorge, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(x1) + 2.5, 2.5 + float(index) * 4.0, 0, q2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(cx) + 0.5, float(middle) - 4.5, 4, q2_foe(dice, self.danger, False, True), 180.0);
        # Halfway over, charges go off along the bridge, one after another,
        # and guards appear on the far side.
        halfway = build.touch(float(cx - 1), float(middle - 2), 0.0, float(cx + 1), float(middle + 2), 6.0);
        charges(build, halfway, [[float(cx - 3) + 0.5, float(middle - 3), -2.0], [float(cx) + 0.5, float(middle + 3), -2.0], [float(cx + 3) + 0.5, float(middle - 3), -2.0]], 0.3);
        far_side = build.waiting();
        halfway +>:Fires:+> far_side;
        build.touch(1.0, float(middle - 2), 0.0, 3.0, float(middle + 2), 6.0, True, "Watch the bridge: the base's charges are wired along it");
        for index in range(dice.between(1, 2)) {
            build.foe(float(x1) + 3.5, float(middle) + 2.5 - float(index) * 5.0, 0, q2_foe(dice, self.danger), 180.0, waits=far_side);
        }
        build.foe(float(x1) + 1.5, 2.5, 0, "monster_soldier", 90.0, patrol=[[float(x1) + 1.5, 2.5], [float(x1) + 1.5, float(self.wide) - 2.5]]);
        build.foe(float(x0 + self.deep + 3) + 0.5, 3.5, low, q2_foe(dice, self.danger), 90.0);
        sparking(build, float(x1) - 0.2, float(middle) - 4.5, -2.0, 2, 4.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(x0) + 2.5, float(self.wide) - 2.5, low, "ammo_bullets", "q2");
    }
}

"""A yard round a control tower (hollow, a control room in its foot, or
solid), a ramp up to its top and walkways from it to ways on high in two
walls."""
node ControlYard(Prefab) {
    has tower: int = 7,
        tall: int = 22,
        hollow: bool = False,
        cargo: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Control yard";
        self.source = BASE1;
        self.district = level_district(BASE1);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.hollow = dice.chance(0.6);
        self.cargo = dice.chance(0.5);
        self.tower = dice.between(8, 9) if self.hollow else dice.between(7, 8);
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
        # The control room in the tower's foot, its door on the north face
        # under the walkway; its console establishes the link, and charges
        # and guards answer.
        if self.hollow {
            room = build.room(tx0 + 1, ty0 + 1, 0, tx1 - 1, ty1 - 1, self.tower - 1);
            build.widen(room, cx - 1, ty1 - 1, 0, cx + 2, ty1, 5);
            build.solid(tx0 + 1, ty0 + 1, 0, tx0 + 2, ty0 + 3, 2);
            build.solid(tx1 - 2, ty0 + 1, 0, tx1 - 1, ty0 + 3, 2);
            console = build.push(float(cx) + 0.5, float(ty0 + 1), 2.0, 1);
            console +>:Fires:+> build.objective("Communication link established. Find the security pass for the base's inner door");
            charges(build, console, [[float(tx0) - 2.5, float(ty1) + 3.5, 1.0], [float(tx1) + 2.5, float(ty1) + 3.5, 1.0]], 0.4);
            answer = build.waiting();
            console +>:Fires:+> answer;
            for index in range(dice.between(1, 2)) {
                build.foe(float(tx0) - 2.5 + float(index) * 6.0, float(ty1) + 4.5, 0, q2_foe(dice, self.danger), 270.0, waits=answer);
            }
            sparking(build, float(tx1 - 1) - 0.2, float(cy) + 0.5, 2.5, 2, 3.0);
            build.supply(float(tx0) + 2.0, float(ty1) - 2.0, 0, Q2_HEALTH, "q2");
        }
        # A cargo lift riding up and down the tower's west face.
        if self.cargo {
            build.train([3.0, 3.0, 1.0], [[float(tx0 - 3), float(cy - 1), 0.0], [float(tx0 - 3), float(cy - 1), float(self.tower - 1)]], 70.0, 3.0);
            for y in range(cy - 1, cy + 2) {
                build.keep(yard, tx0, y, self.tower);
            }
        }
        for index in range(dice.between(3, 4)) {
            build.foe(float(4 + index * 5) + 0.5, 3.5 + float(index % 2) * (float(self.wide) - 7.0), 0, q2_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, self.tower, q2_foe(dice, self.danger, True), 180.0);
        # The tower's panels spark; guards walk round it and along the
        # east walkway.
        sparking(build, float(tx1) + 0.2, float(ty0) + 1.5, 3.0, 0, 3.0);
        sparking(build, float(tx0) + 1.5, float(ty1) + 0.2, 3.0, 1, 5.0);
        build.foe(float(tx0) - 1.5, float(ty1) + 1.5, 0, "monster_soldier", 0.0, patrol=[[float(tx0) - 1.5, float(ty1) + 1.5], [float(tx1) + 1.5, float(ty1) + 1.5], [float(tx1) + 1.5, float(ty0) - 4.5], [float(tx0) - 3.5, float(ty0) - 4.5]]);
        build.foe(float(tx1) + 1.5, float(cy) + 0.5, self.tower, "monster_soldier_light", 0.0, patrol=[[float(tx1) + 1.5, float(cy) + 0.5], [float(self.long) - 3.5, float(cy) + 0.5]]);
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
        build.supply(3.5, float(self.wide) - 3.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.5, 3.5, 0, Q2_HEALTH, "q2");
    }
}

"""The base's elevator: a landing over a shaft room, the elevator riding
between them, a stair down the wall beside it."""
node BaseElevator(Prefab) {
    has drop: int = 12,
        landing: int = 7,
        tall: int = 22,
        down: bool = True,
        called: bool = False,
        stair_low: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Base elevator";
        self.source = BASE1;
        self.district = level_district(BASE1);
        self.drop = dice.between(12, 14);
        self.landing = dice.between(6, 7);
        self.long = self.landing + self.drop + dice.between(6, 8);
        self.wide = dice.between(15, 17);
        self.tall = self.drop + dice.between(9, 10);
        self.down = dice.chance(0.6);
        self.called = dice.chance(0.5);
        self.stair_low = dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        far = float(self.long) - 5.0;
        if self.down {
            self.enter = Port(face=2, along=middle, floor=self.drop);
            self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1 if self.stair_low else 3, along=far, floor=0)];
        } else {
            self.enter = Port(face=2, along=middle, floor=0);
            self.leaves = [Port(face=3 if self.stair_low else 1, along=float(self.landing // 2) + 1.0, floor=self.drop), Port(face=0, along=middle, floor=0)];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.drop);
        # The landing, a deck over the shaft room's near end; the elevator's
        # car beside it, four cells square.
        edge_x = 1 + self.landing;
        deck(build, 1, 1, edge_x, self.wide - 1, self.drop);
        car_y = middle - 2;
        ride = build.train([4.0, 4.0, 1.0], [[float(edge_x), float(car_y), float(self.drop - 1)], [float(edge_x), float(car_y), -1.0]], 90.0, 3.0, self.called);
        for y in range(car_y, car_y + 4) {
            build.keep(shaft, edge_x - 1, y, self.drop);
        }
        if self.called {
            # Called from the landing or from the floor below.
            build.push(1.0, float(car_y) - 1.5, float(self.drop) + 2.0, 0) +>:Fires:+> ride;
            build.push(float(self.long - 1), float(middle) + 3.5, 2.5, 2) +>:Fires:+> ride;
        }
        # The stair down the side wall beside the car, a lift a cell.
        stair_y = 1 if self.stair_low else self.wide - 4;
        stair(build, edge_x + self.drop - 1, stair_y, 0, 2, self.drop, 3);
        for y in range(stair_y, stair_y + 3) {
            build.keep(shaft, edge_x - 1, y, self.drop);
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        top_y = float(middle) + 3.5;
        build.touch(1.0, 1.0, float(self.drop), 4.0, float(self.wide - 1), float(self.drop + 6)) +>:Fires:+> build.objective("Take the base elevator down into the installation", False);
        # Guards appear on the floor below as the car comes down to it.
        arrive = build.touch(float(edge_x), float(car_y), 0.0, float(edge_x + 4), float(car_y + 4), 4.0);
        guards = build.waiting();
        arrive +>:Fires:+> guards;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, 3.5 + float(index) * 4.0, 0, q2_foe(dice, self.danger, index == 1), 180.0, waits=guards);
        }
        build.supply(float(edge_x) + 6.5, float(middle) - 3.5, 0, Q2_HEALTH, "q2");
        build.touch(float(edge_x + 4), 1.0, 0.0, float(edge_x + 6), float(self.wide - 1), 6.0, True, "The base installation lies beyond");
        build.foe(3.5, top_y, self.drop, q2_foe(dice, self.danger), 0.0);
        build.foe(float(edge_x) + 6.5, float(middle) + 4.5, 0, "monster_soldier", 90.0, patrol=[[float(edge_x) + 6.5, float(middle) + 4.5], [float(self.long) - 3.5, float(middle) + 4.5]]);
        # Under the landing, its machinery sparking.
        sparking(build, 1.2, float(middle) + 0.5, 2.0, 0, 4.0);
        sparking(build, float(self.long - 1) - 0.2, float(middle) - 4.5, 3.0, 2, 6.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(2.5, float(self.wide) - 2.5, self.drop, Q2_AMMO[dice.below(len(Q2_AMMO))], "q2");
    }
}

"""A two-floor control room, a gallery round its walls up two stairs,
consoles in the middle; the console on the gallery sends the message."""
node CommCenter(Prefab) {
    has gallery: int = 9,
        tall: int = 18,
        twin: bool = True,
        dais: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Comm center";
        self.source = BASE1;
        self.district = level_district(BASE1);
        self.gallery = dice.between(9, 10);
        self.long = dice.between(24, 27);
        self.wide = dice.between(19, 21);
        self.tall = self.gallery + dice.between(9, 10);
        self.twin = dice.chance(0.6);
        self.dais = dice.chance(0.5);
        self.low = -1;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long // 2), floor=self.gallery), Port(face=3, along=float(self.long // 2), floor=self.gallery)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        g = self.gallery;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The gallery round the walls, three cells deep.
        deck(build, 1, 1, self.long - 1, 4, g);
        deck(build, 1, self.wide - 4, self.long - 1, self.wide - 1, g);
        deck(build, 1, 4, 4, self.wide - 4, g);
        deck(build, self.long - 4, 4, self.long - 1, self.wide - 4, g);
        # The stairs up to it: one climbing along the south side, and (when
        # `twin`) one back along the north side.
        stair(build, 5, 4, 0, 0, g, 3);
        for x in range(4 + g - 2, 5 + g) {
            build.keep(hall, x, 3, g);
        }
        if self.twin {
            stair(build, self.long - 6, self.wide - 7, 0, 2, g, 3);
            for x in range(self.long - 5 - g, self.long - 3 - g + 2) {
                build.keep(hall, x, self.wide - 4, g);
            }
        }
        # A stretch of the gallery's inner edge unrailed on the east side, to
        # drop to the floor.
        for y in range(middle + 3, middle + 6) {
            build.keep(hall, self.long - 4, y, g);
        }
        # Consoles down the middle (on a low dais, or on the floor).
        if self.dais {
            build.solid(9, middle - 3, 0, self.long - 9, middle + 3, 1);
        }
        for x in range(10, self.long - 10, 3) {
            build.solid(x, middle - 1, 0, x + 2, middle + 1, 3 if self.dais else 2);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # The console on the gallery's far side sends the message: the
        # objective moves on, charges go off and guards appear below.
        console = build.push(float(self.long - 1), float(middle) + 0.5, float(g) + 1.2, 2);
        console +>:Fires:+> build.objective("Message sent. Find the security pass for the base's inner door", False);
        charges(build, console, [[6.5, float(middle) - 4.5, 2.0], [float(self.long) - 6.5, float(middle) + 4.5, 2.0], [float(self.long // 2) + 0.5, float(middle) + 0.5, 4.0]], 0.3);
        answer = build.waiting();
        console +>:Fires:+> answer;
        for index in range(dice.between(1, 2)) {
            build.foe(6.5 + float(index) * 6.0, float(middle) + 3.5, 0, q2_foe(dice, self.danger, index == 1), 0.0, waits=answer);
        }
        build.supply(2.5, float(middle) + 3.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, g, Q2_ARMOR, "q2");
        build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 3), 6.0, True, "Send the message from the gallery's console");
        # The guards: one walking the gallery, others on the floor.
        build.foe(2.5, 2.5, g, "monster_soldier", 0.0, patrol=[[2.5, 2.5], [float(self.long) - 2.5, 2.5], [float(self.long) - 2.5, float(self.wide) - 2.5], [2.5, float(self.wide) - 2.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 6.5, 6.5 + float(index) * 6.0, 0, q2_foe(dice, self.danger), 180.0);
        }
        sparking(build, 1.2, float(middle) - 4.5, 2.0, 0, 5.0);
        sparking(build, float(self.long // 2) + 5.5, 1.2, float(g) + 2.0, 1, 3.5);
        build.supply(float(self.long) - 2.5, 2.5, g, Q2_HEALTH, "q2");
        build.supply(6.5, float(middle) + 0.5, 0, Q2_AMMO[dice.below(len(Q2_AMMO))], "q2");
    }
}

"""The key on a control deck up a lift (or a stair); taking it opens the
closets."""
node SecurityRoom(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        deck_top: int = 6,
        tall: int = 14,
        stair_up: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Security room (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = BASE1;
        self.district = level_district(BASE1);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.stair_up = dice.chance(0.5);
        self.deck_top = dice.between(6, 7) if self.stair_up else dice.between(5, 7);
        self.tall = self.deck_top + 8;
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
        build.level(room, self.deck_top);
        build.doorway(room, self.enter);
        dx = self.long - 6;
        if self.stair_up {
            # The deck over the floor's far end, climbed by a stair along the
            # wall; cabinets stored under it.
            deck(build, dx, 2, self.long - 1, side - 1, self.deck_top);
            stair(build, dx - self.deck_top, 2, 0, 0, self.deck_top, 3);
            for y in range(2, 5) {
                build.keep(room, dx, y, self.deck_top);
            }
            build.solid(self.long - 3, side - 5, 0, self.long - 1, side - 2, 2);
            build.supply(float(dx) + 1.5, float(cy) + 0.5, 0, Q2_AMMO[dice.below(len(Q2_AMMO))], "q2");
        } else {
            build.solid(dx, 2, 0, self.long - 1, side - 1, self.deck_top);
            build.put_box({"classname": "func_plat", "height": str(self.deck_top * 16), "speed": "200"}, float(dx - 3), float(cy - 1), float(self.deck_top) - 0.5, float(dx), float(cy + 2), float(self.deck_top), kit_of(build.district).step);
            for y in range(cy - 2, cy + 3) {
                build.keep(room, dx, y, self.deck_top);
            }
        }
        # Consoles along the deck's back wall.
        build.solid(self.long - 2, 3, self.deck_top, self.long - 1, side - 2, self.deck_top + 2);
        # The key: taking it opens the closets and moves the objective on.
        fields = {"classname": key_item(self.key), "asset_game": "q1"};
        build.put_at(fields, float(self.long) - 3.5, float(cy) + 0.5, self.deck_top);
        taken = build.cue([fields], "key");
        taken +>:Fires:+> build.objective("You have the pass. Get to the inner door");
        build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 3), 6.0) +>:Fires:+> build.objective("The security pass is on the control deck", False);
        for (index, at) in enumerate([2, dx - 6]) {
            closet = build.room(at, side + 1, 0, at + 3, side + 4, 7);
            build.widen(closet, at, side, 0, at + 3, side + 1, 6);
            taken +>:Fires:+> build.opened(float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0);
            build.foe(float(at) + 1.5, float(side) + 2.5, 0, q2_foe(dice, self.danger, index == 0), 270.0);
        }
        # A vent panel low in the near wall breaks open on a stash.
        stash(build, 1, 2, 0, 0, base1_reward(dice), "q2", True);
        build.foe(float(self.long) - 3.5, 3.5, self.deck_top, q2_foe(dice, self.danger), 180.0);
        build.foe(6.5, float(cy) + 0.5, 0, "monster_soldier_light", 0.0, patrol=[[6.5, float(cy) + 0.5], [float(dx) - 4.5, float(cy) + 0.5]]);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
        sparking(build, float(self.long) - 2.2, float(cy) - 3.5, float(self.deck_top) + 1.5, 2, 6.0);
        sparking(build, 1.2, float(cy) + 3.5, 2.5, 0, 4.5);
    }
}

"""The end: a door out to a pad under the sky, the way out on it, low or
high on a tower up a lift."""
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
        self.pad = dice.between(8, 10) if dice.chance(0.5) else dice.between(1, 2);
        self.tall = max(dice.between(18, 22), self.pad + 12);
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
        if self.pad > 4 {
            # A tower: the pad high on it, the lift up its near face.
            lift(build, px - 3, middle - 1, px, middle + 2, 0, self.pad);
            for y in range(middle - 1, middle + 2) {
                build.keep(yard, px, y, self.pad);
            }
            build.touch(float(px) - 5.0, float(middle - 2), 0.0, float(px - 3), float(middle + 3), 6.0, True, "Ride the lift up to the landing pad");
        } else {
            stair(build, px - self.pad, middle - 2, 0, 0, self.pad, 4);
        }
        build.way_out(float(px) + 4.0, float(middle), self.pad);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, q2_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, 2.5, 0, q2_foe(dice, self.danger, True), 180.0);
        build.foe(float(px) + 2.5, float(middle) + 6.5, self.pad + 4, q2_foe(dice, self.danger, False, True), 180.0);
        # Out in the yard, guards appear; on the pad, its charges go off.
        out_touch = build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0);
        yard_guard = build.waiting();
        out_touch +>:Fires:+> yard_guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(px) - 3.5, 2.5 + float(index) * (float(self.wide) - 5.0), 0, q2_foe(dice, self.danger), 0.0, waits=yard_guard);
        }
        build.foe(float(wall) + 3.5, 2.5, 0, "monster_soldier", 0.0, patrol=[[float(wall) + 3.5, 2.5], [float(px) - 2.5, 2.5], [float(px) - 2.5, float(self.wide) - 2.5], [float(wall) + 3.5, float(self.wide) - 2.5]]);
        on_pad = build.touch(float(px), float(middle - 5), float(self.pad), float(px + 2), float(middle + 5), float(self.pad + 6));
        charges(build, on_pad, [[float(self.long) - 2.5, float(middle - 6) + 0.5, 3.0], [float(self.long) - 2.5, float(middle + 6) + 0.5, 3.0]], 0.4);
        sparking(build, float(wall) + 0.2, float(middle) + 3.5, 3.0, 0, 5.0);
        build.touch(1.0, float(middle - 2), 0.0, 4.0, float(middle + 2), 6.0) +>:Fires:+> build.objective("Get to the landing pad and out");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(wall) + 2.5, float(self.wide) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""base1's stretches: [name, role]."""
glob BASE1_STRETCHES: list[list[str]] = [
         ["canyon", "start"],
         ["bridge", "flow"],
         ["yard", "hub"],
         ["yard", "flow"],
         ["elevator", "flow"],
         ["comm", "flow"],
         ["comm", "hub"],
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
    if name == "elevator" {
        return BaseElevator();
    }
    if name == "comm" {
        return CommCenter();
    }
    if name == "security" {
        return SecurityRoom(key=key if key else "key_silver");
    }
    return LandingPad(key=key);
}
