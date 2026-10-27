"""Prefabs drawn from Quake II's mine3, the Drilling Area: a drilling
cavern, a pier out over its pit to the drill's platform; an access bridge
lowered from a service gallery; a chamber sealed until two charges are
shot; a hall round a great drill rig; a shaft climbed by service
elevators; the key among core samples; and the drill that cuts a new
passage to the lower mines. Raised in mine3's own palette.

- `DrillPlatform`: the start. A cavern, its floor ending at a pit, a pier
  out over the pit to the drill's platform, the drill head riding up and
  down through it; a stair down into the pit; the sealed door ("Drilling
  area. Access denied") and the objective ("Lower the access bridge");
  guards walk the floor and the pit, more come out of the pit as the
  player steps onto the pier; a panel in the pit's wall breaks open on a
  stash (the secret). Ways on from the platform, the floor and the pit.
- `AccessBridge`: a chasm over lava, a service gallery along its side
  reached by a stair or a service elevator, the switch at its end that
  lowers the access bridge ("Access bridge lowered"); guards appear on the
  far ledge as it comes down.
- `ChargeChamber`: a hall with galleries along both sides and a bridge
  between them, drill pistons pumping in its floor; its ways on are sealed
  ("Access denied") until the two charges high on its end walls are shot
  (mine3's counter of two charges), which blow, open the ways and bring
  a heavy one in (a hub).
- `DrillRig`: a hall round a great drill rig, a stair or an elevator up
  its side to a walk round its top and bridges out to the walls; guards
  walk round it and come out as the player reaches the top, a panel in it
  breaks open on a stash (a hub).
- `ServiceShaft`: a shaft climbed ledge over ledge by service elevators (or
  an elevator and a stair); each ledge's guards come as the player reaches
  the one below.
- `CoreSamples`: the key among core samples on a rack up steps; taking it
  opens the closets; a guard walks the floor.
- `DrillBreak`: the end. A door (a key's, as a gate), a hall with the drill
  on its bed against a rock face; the drill's control on a pulpit sets it
  going: charges go off along the face, it opens on the way out ("New
  passage to lower mines created")."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, boulders, key_ambush, gate_into, lift }
import from .minefact { slab, hurt, burning, sparking, stash, charges, port_door, sealed, press, cart }

glob MINE3: str = "q2:mine3";

"""mine3's foes: soldiers and gunners, gladiators, a tank or a mutant
deeper in."""
def mine3_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_gladiator"] if heavy else ["monster_soldier", "monster_gunner", "monster_soldier_light"], ["monster_tank", "monster_mutant"] if heavy else ["monster_mutant"], danger * 0.4 if heavy else danger * 0.7));
}

"""The start: a cavern, a pier out over its pit to the drill's platform."""
node DrillPlatform(Prefab) {
    has deep: int = 9,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drill platform";
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.long = dice.between(28, 32);
        self.wide = dice.between(20, 24);
        self.deep = dice.between(8, 10);
        self.tall = dice.between(13, 15);
        self.low = -self.deep - 1;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy), floor=0);
        self.leaves = [
            Port(face=0, along=float(cy), floor=0),
            Port(face=1, along=float(dice.between(13, self.long - 12)), floor=-self.deep),
            Port(face=3, along=float(dice.between(3, 7)), floor=0),
            Port(face=1, along=float(dice.between(3, 7)), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        kit = kit_of(build.district);
        cy = self.wide // 2;
        low = -self.deep;
        cave = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(cave, 0);
        build.level(cave, low);
        # The floor ends at the pit; the pier out over it to the platform.
        build.solid(1, 1, low, 10, self.wide - 1, 0);
        slab(build, 10, cy - 2, self.long - 9, cy + 2, 0, 2);
        slab(build, self.long - 9, cy - 5, self.long - 1, cy + 5, 0, 2);
        # The drill head riding up and down through a hole in the platform.
        build.widen(cave, self.long - 6, cy - 1, -2, self.long - 4, cy + 1, 0);
        press(build, float(self.long - 6), float(cy - 1), [2.0, 2.0, 2.0], float(low), -2.0, 40.0, 2.0);
        stair(build, 10 + self.deep - 1, 1, low, 2, self.deep, 3);
        for y in range(1, 4) {
            build.keep(cave, 9, y, 0);
        }
        for y in range(cy - 2, cy + 2) {
            build.keep(cave, 9, y, 0);
        }
        # The stash in the pit's wall under the floor.
        stash(build, 7, cy + 3, low, 0, Q2_ARMOR);
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        sealed(build, self.long, self.wide, self.enter, kit.door);
        build.touch(1.0, float(cy - 2), 0.0, 3.0, float(cy + 2), 6.0, True, "Drilling area. Access denied.");
        build.start(4.5, float(cy) + 0.5, 0, 0.0);
        build.supply(4.5, float(cy) - 2.5, 0, "ammo_shells", "q2");
        build.touch(3.0, float(cy - 3), 0.0, 7.0, float(cy + 3), 6.0) +>:Fires:+> build.objective("Lower the access bridge. Find the service switch.");
        sparking(build, float(self.long) - 4.0, float(cy) + 1.2, 2.0, 1, 3.0);
        # Stepping onto the pier brings guards up out of the pit.
        pier = build.touch(10.0, float(cy - 2), 0.0, 13.0, float(cy + 2), 6.0);
        pit = build.waiting();
        pier +>:Fires:+> pit;
        pier +>:Fires:+> build.summon(2, 2, low + 1, "monster_gunner", float(self.long) - 3.5, float(cy) - 3.5, 0, 180.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(14 + index * 4) + 0.5, float(self.wide) - 3.5, low, mine3_foe(dice, self.danger), 270.0, waits=pit);
        }
        ring = [[12.5, 5.5], [float(self.long) - 3.5, 5.5], [float(self.long) - 3.5, float(self.wide) - 3.5], [12.5, float(self.wide) - 3.5]];
        build.foe(ring[0][0], ring[0][1], low, "monster_soldier", 0.0, patrol=ring);
        build.foe(7.5, 3.5, 0, "monster_soldier_light", 90.0, patrol=[[7.5, 3.5], [7.5, float(self.wide) - 3.5]]);
        build.foe(float(self.long) - 3.5, float(cy) + 3.5, 0, mine3_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 2.5, float(cy) - 3.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 0.5, 3.5, low, "ammo_bullets", "q2");
    }
}

"""A chasm over lava, a service gallery along its side, the switch at
its end that lowers the access bridge."""
node AccessBridge(Prefab) {
    has span: int = 11,
        deep: int = 11,
        by_stair: bool = True,
        gallery: int = 8,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Access bridge";
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.span = dice.between(10, 12);
        self.long = 9 + self.span + 3 + 1;
        self.wide = dice.between(18, 20);
        self.deep = dice.between(10, 12);
        self.gallery = 8;
        self.by_stair = dice.chance(0.5);
        self.tall = self.gallery + dice.between(7, 9);
        self.low = -2 * self.deep - 4;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=3.0 if self.by_stair else float(dice.between(3, cy - 3)), floor=0);
        self.leaves = [Port(face=0, along=float(cy), floor=0)];
        if dice.chance(0.3) {
            self.leaves.append(Port(face=1, along=6.0, floor=self.gallery));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.deep;
        cy = self.wide // 2;
        x0 = 9;
        x1 = 9 + self.span;
        chasm = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(chasm, 0);
        build.level(chasm, self.gallery);
        build.solid(1, 1, low, x0, self.wide - 1, 0);
        build.solid(x1, 1, low, self.long - 1, self.wide - 1, 0);
        burning(build, x0, 1, low, x1, self.wide - 1, low + 3, 4);
        # The service gallery along the north wall over the ledge and the
        # chasm; up to it by a stair or a service elevator.
        gy = self.wide - 5;
        slab(build, 1, gy, x1 - 3, self.wide - 1, self.gallery, 1);
        if self.by_stair {
            stair(build, 1, gy - self.gallery, 0, 1, self.gallery, 3);
        } else {
            cart(build, [[4.0, float(gy - 3), 0.0], [4.0, float(gy - 3), float(self.gallery - 1)]], 70.0, 2.0);
            for x in range(4, 7) {
                build.keep(chasm, x, gy, self.gallery);
            }
        }
        build.doorway(chasm, self.enter);
        for port in self.taken {
            build.doorway(chasm, port);
        }
        for y in range(cy - 2, cy + 2) {
            build.keep(chasm, x0 - 1, y, 0);
            build.keep(chasm, x1, y, 0);
        }
        # The service switch at the gallery's end lowers the access bridge.
        service = build.push(float(x1) - 4.5, float(self.wide - 1), float(self.gallery) + 1.0, 3);
        lowered = build.drawn(float(x0), float(cy - 2), float(x1), float(cy + 2), 0, self.deep + 1);
        service +>:Fires:+> lowered;
        # A switch on the far ledge's wall lowers it too, for a body come
        # round to the far side.
        build.push(float(self.long - 1), float(cy) + 3.5, 1.0, 2) +>:Fires:+> lowered;
        service +>:Fires:+> build.objective("Access bridge lowered. Find the drill controls.");
        build.touch(float(x0 - 3), float(cy - 3), 0.0, float(x0), float(cy + 3), 6.0, True, "Lower the access bridge. Find the service switch.");
        far_ledge = build.waiting();
        service +>:Fires:+> far_ledge;
        service +>:Fires:+> build.summon(2, 2, low + 1, mine3_foe(dice, self.danger, True), float(x1) + 1.5, float(cy) - 0.5, 0, 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(x1) + 1.5, float(cy) + (2.5 if index == 0 else -3.5), 0, mine3_foe(dice, self.danger), 180.0, waits=far_ledge);
        }
        gallery_y = float(gy) + 2.0;
        build.foe(5.5, gallery_y, self.gallery, "monster_soldier", 0.0, patrol=[[5.5, gallery_y], [float(x1) - 5.5, gallery_y]]);
        build.foe(4.5, 3.5, 0, "monster_soldier_light", 0.0, patrol=[[4.5, 3.5], [float(x0) - 1.5, 3.5]]);
        build.foe(float(x0 + x1) * 0.5, float(cy) - 4.5, 5, mine3_foe(dice, self.danger, True), 90.0);
        sparking(build, float(x1) - 4.5, float(self.wide) - 1.1, float(self.gallery) + 3.0, 3, 4.0);
        build.supply(2.5, 6.5, 0, Q2_HEALTH, "q2");
        build.supply(float(x1) - 6.5, gallery_y, self.gallery, "ammo_bullets", "q2");
    }
}

"""A hall with galleries along both sides and a bridge between, sealed
until the two charges high on its end walls are shot."""
node ChargeChamber(Prefab) {
    has deck: int = 7,
        bridge_x: int = 14,
        floor_door: int = 10,
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Charge chamber";
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.long = dice.between(26, 30);
        self.wide = dice.between(22, 26);
        self.deck = 7;
        self.tall = dice.between(15, 17);
        self.bridge_x = dice.between(10, self.long - 12);
        self.floor_door = dice.between(8, self.wide - 9);
        self.low = -13;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(8, self.wide - 9)), floor=0);
        self.leaves = [
            Port(face=1, along=float(dice.between(8, self.long - 9)), floor=self.deck),
            Port(face=0, along=float(self.floor_door), floor=0),
            Port(face=3, along=float(dice.between(8, self.long - 9)), floor=self.deck),
            Port(face=0, along=float(self.wide - 3), floor=self.deck)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        d = self.deck;
        bx = self.bridge_x;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, d);
        # The galleries along both long walls, the bridge across between
        # them, a stair up to each.
        slab(build, 1, 1, self.long - 1, 5, d, 1);
        slab(build, 1, self.wide - 5, self.long - 1, self.wide - 1, d, 1);
        slab(build, bx, 5, bx + 4, self.wide - 5, d, 1);
        stair(build, 3, 4 + d, 0, 3, d, 3);
        stair(build, self.long - 6, self.wide - 5 - d, 0, 1, d, 3);
        for x in range(3, 6) {
            build.keep(hall, x, 4, d);
        }
        for x in range(self.long - 6, self.long - 3) {
            build.keep(hall, x, self.wide - 5, d);
        }
        # Drill pistons pumping in holes in the floor.
        for at in [[8, 8], [self.long - 10, self.wide - 10]] {
            build.widen(hall, at[0], at[1], -6, at[0] + 2, at[1] + 2, 0);
            press(build, float(at[0]), float(at[1]), [2.0, 2.0, 4.0], -6.0, -4.0, 120.0, 1.0);
        }
        build.breakable(float(self.long - 3), 1.0, float(d), float(self.long - 1), 3.0, float(d + 2), 30);
        build.breakable(1.0, float(self.wide - 3), float(d), 3.0, float(self.wide - 1), float(d + 2), 30);
        build.doorway(hall, self.enter);
        # The two charges high on the end walls: shot, each blows; both open
        # the ways on and bring a heavy one in.
        cleared = build.tally(2, "Access granted.");
        east = build.push(float(self.long - 1), 3.0, float(d + 3), 2, True);
        west = build.push(1.0, float(self.wide) - 3.0, float(d + 3), 0, True);
        east +>:Fires:+> cleared;
        west +>:Fires:+> cleared;
        charges(build, east, [[float(self.long) - 1.5, 3.0, float(d + 4)], [float(self.long) - 2.5, 5.0, float(d + 2)]], 0.3);
        charges(build, west, [[1.5, float(self.wide) - 3.0, float(d + 4)], [2.5, float(self.wide) - 5.0, float(d + 2)]], 0.3);
        build.touch(1.0, self.enter.along - 2.0, 0.0, 4.0, self.enter.along + 2.0, 6.0, True, "Access denied. Shoot the charges.");
        for port in self.taken {
            build.doorway(hall, port);
            port_door(build, self.long, self.wide, port, cleared);
        }
        cleared +>:Fires:+> build.summon(self.long - 5, 2, -6 - 6, mine3_foe(dice, self.danger, True), float(self.long // 2) + 0.5, float(self.wide // 2) + 0.5, 0, 180.0);
        # Guards on the floor come as the player walks in; each gallery's as
        # the player reaches it.
        come_in = build.touch(1.0, 5.0, 0.0, 5.0, float(self.wide - 5), 6.0);
        floor_guard = build.waiting();
        come_in +>:Fires:+> floor_guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long - 5) + 0.5, float(7 + index * 4) + 0.5, 0, mine3_foe(dice, self.danger), 180.0, waits=floor_guard);
        }
        south_top = build.touch(3.0, 1.0, float(d), 6.0, 5.0, float(d + 6));
        north_guard = build.waiting();
        south_top +>:Fires:+> north_guard;
        build.foe(float(self.long) - 4.5, float(self.wide) - 3.0, d, mine3_foe(dice, self.danger), 180.0, waits=north_guard);
        build.foe(6.5, 3.0, d, "monster_soldier", 0.0, patrol=[[6.5, 3.0], [float(self.long) - 3.5, 3.0]]);
        build.foe(float(self.long) - 8.5, float(self.wide) - 3.0, d, "monster_soldier", 180.0, patrol=[[float(self.long) - 8.5, float(self.wide) - 3.0], [3.5, float(self.wide) - 3.0]]);
        mid_y = float(self.wide // 2) + 0.5;
        build.foe(6.5, mid_y, 0, "monster_gunner", 0.0, patrol=[[6.5, mid_y], [float(self.long) - 4.5, mid_y]]);
        build.supply(float(bx) + 2.0, float(self.wide // 2) + 0.5, d, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.5, float(self.wide // 2) - 3.5, 0, "ammo_bullets", "q2");
    }
}

"""A hall round a great drill rig, a stair or an elevator up its side to
a walk round its top and bridges out to the walls."""
node DrillRig(Prefab) {
    has rig: int = 8,
        way_up: int = 0,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drill rig";
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.long = dice.between(28, 30);
        self.wide = dice.between(26, 28);
        self.rig = dice.between(7, 8);
        self.way_up = dice.below(3);
        self.tall = self.rig + 13;
        self.low = -11;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.rig),
            Port(face=0, along=middle, floor=self.rig),
            Port(face=3, along=float(self.long // 2) + 6.0, floor=0),
            Port(face=1, along=5.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, self.rig);
        # The rig: a block, its drill column up through the roof, the walk
        # round its top; bridges north and east to the walls.
        build.solid(cx - 4, cy - 4, 0, cx + 4, cy + 4, self.rig);
        build.solid(cx - 1, cy - 1, self.rig, cx + 1, cy + 1, self.tall);
        if self.way_up == 0 {
            stair(build, cx - 4, cy - 4 - self.rig, 0, 1, self.rig, 3);
        } elif self.way_up == 1 {
            cart(build, [[float(cx - 4), float(cy - 7), 0.0], [float(cx - 4), float(cy - 7), float(self.rig - 1)]], 60.0, 2.5);
        } else {
            # Steps that rise out of the floor when the switch on the rig's
            # foot is pressed.
            build.push(float(cx) + 1.5, float(cy - 4), 1.0, 3) +>:Fires:+> build.rising_steps(cx - 4, cy - 4 - self.rig, 0, 1, self.rig, 3);
        }
        # Sample cases on the floor, that break when shot.
        build.breakable(2.0, 2.0, 0.0, 4.0, 4.0, 2.0, 30);
        build.breakable(float(self.long - 4), float(self.wide - 4), 0.0, float(self.long - 2), float(self.wide - 2), 2.0, 30);
        build.solid(cx - 2, cy + 4, self.rig - 1, cx + 2, self.wide - 1, self.rig);
        build.solid(cx + 4, cy - 2, self.rig - 1, self.long - 1, cy + 2, self.rig);
        for at in range(-2, 2) {
            build.keep(hall, cx + at, cy + 3, self.rig);
            build.keep(hall, cx + 3, cy + at, self.rig);
        }
        for x in range(cx - 4, cx - 1) {
            build.keep(hall, x, cy - 4, self.rig);
        }
        # A stash in the rig's west face, behind a panel.
        stash(build, cx - 3, cy + 1, 0, 2, "ammo_grenades");
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # Guards walk round the rig; at its top more come and one is sent in.
        ring = [[float(cx) - 6.5, float(cy) - 6.5], [float(cx) + 6.5, float(cy) - 6.5], [float(cx) + 6.5, float(cy) + 6.5], [float(cx) - 6.5, float(cy) + 6.5]];
        build.foe(ring[0][0], ring[0][1], 0, "monster_soldier", 0.0, patrol=ring);
        build.foe(ring[2][0], ring[2][1], 0, "monster_gunner", 180.0, patrol=[ring[2], ring[3], ring[0], ring[1]]);
        at_top = build.touch(float(cx - 4), float(cy - 4), float(self.rig), float(cx - 1), float(cy - 2), float(self.rig + 6));
        top_guard = build.waiting();
        at_top +>:Fires:+> top_guard;
        build.foe(float(cx) + 2.5, float(cy) + 2.5, self.rig, mine3_foe(dice, self.danger, True), 180.0, waits=top_guard);
        build.foe(float(self.long) - 3.5, float(cy) + 0.5, self.rig, mine3_foe(dice, self.danger), 180.0, waits=top_guard);
        at_top +>:Fires:+> build.summon(1, self.wide - 5, -9, mine3_foe(dice, self.danger), float(cx) - 8.5, float(cy) + 6.5, 0, 0.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(4 + index * 18) + 0.5, 3.5 + float(index % 2) * (float(self.wide) - 7.0), 0, mine3_foe(dice, self.danger), 0.0);
        }
        sparking(build, float(cx) + 1.1, float(cy) + 0.5, float(self.rig) + 3.0, 0, 3.0);
        build.supply(float(cx) - 2.5, float(cy) + 2.5, self.rig, Q2_ARMOR, "q2");
        build.supply(3.0, 3.0, 0, Q2_HEALTH, "q2");
    }
}

"""A shaft climbed ledge over ledge by service elevators."""
node ServiceShaft(Prefab) {
    has first: int = 8,
        second: int = 16,
        stair_up: bool = False,
        tall: int = 25;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Service shaft";
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.first = dice.between(7, 9);
        self.second = self.first + dice.between(7, 9);
        self.stair_up = dice.chance(0.4);
        self.long = max(dice.between(16, 18), self.second - self.first + 13);
        self.wide = dice.between(15, 17);
        self.tall = self.second + 9;
        self.low = -1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 10)), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=self.second), Port(face=1, along=float(self.long // 2), floor=self.first)];
        if dice.chance(0.4) {
            self.leaves.append(Port(face=0, along=3.0, floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, self.first);
        build.level(shaft, self.second);
        north = self.wide - 5;
        rise = self.second - self.first;
        # The first ledge along the north wall, the second along the east
        # wall, each a slab over the floor.
        slab(build, 1, north, self.long - 1, self.wide - 1, self.first, 1);
        slab(build, self.long - 5, 1, self.long - 1, self.wide - 1, self.second, 1);
        cart(build, [[2.0, float(north - 3), 0.0], [2.0, float(north - 3), float(self.first - 1)]], 70.0, 2.0);
        for x in range(2, 5) {
            build.keep(shaft, x, north, self.first);
        }
        if self.stair_up {
            # Steps that rise out of the first ledge when the switch on its
            # wall is pressed, rock under them to sink into.
            build.solid(self.long - 5 - rise, north, 0, self.long - 5, north + 3, self.first);
            build.push(float(self.long - 7 - rise) + 0.5, float(self.wide - 1), float(self.first) + 1.0, 3) +>:Fires:+> build.rising_steps(self.long - 5 - rise, north, self.first, 0, rise, 3);
        } else {
            cart(build, [[float(self.long - 8), float(north - 3), float(self.first - 1)], [float(self.long - 8), float(north - 3), float(self.second - 1)]], 70.0, 2.0);
            for y in range(north - 3, north) {
                build.keep(shaft, self.long - 5, y, self.second);
            }
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # Each ledge's guards come as the player reaches the one below.
        ground = build.touch(2.0, float(north - 3), 0.0, 5.0, float(north), 4.0);
        first_guard = build.waiting();
        ground +>:Fires:+> first_guard;
        build.foe(float(self.long // 2) + 0.5, float(self.wide) - 3.0, self.first, mine3_foe(dice, self.danger), 270.0, waits=first_guard);
        ledge = build.touch(2.0, float(north), float(self.first), 6.0, float(self.wide - 1), float(self.first + 6));
        second_guard = build.waiting();
        ledge +>:Fires:+> second_guard;
        build.foe(float(self.long) - 3.0, 3.5, self.second, mine3_foe(dice, self.danger, True), 90.0, waits=second_guard);
        build.foe(7.5, float(self.wide) - 3.0, self.first, "monster_soldier", 0.0, patrol=[[7.5, float(self.wide) - 3.0], [float(self.long) - 6.5, float(self.wide) - 3.0]]);
        build.foe(float(self.long // 2) + 0.5, 3.5, 0, mine3_foe(dice, self.danger), 90.0);
        sparking(build, 1.1, float(north) - 1.5, 3.0, 0, 4.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.second, Q2_HEALTH, "q2");
    }
}

"""The key among core samples on a rack up steps."""
node CoreSamples(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        rack: int = 3,
        tall: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Core samples (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.rack = dice.between(3, 4);
        self.tall = dice.between(11, 13);
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
        build.level(room, self.rack);
        build.doorway(room, self.enter);
        rx = self.long - 6;
        build.solid(rx, cy - 3, 0, self.long - 1, cy + 3, self.rack);
        stair(build, rx - self.rack, cy - 1, 0, 0, self.rack, 2);
        for y in [cy - 3, cy + 2] {
            for x in range(rx + 1, self.long - 1, 2) {
                build.solid(x, y, self.rack, x + 1, y + 1, self.rack + 3);
            }
        }
        key_ambush(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, self.rack, side, 0, [2, rx - 4], [mine3_foe(dice, self.danger, True), mine3_foe(dice, self.danger)]);
        build.foe(4.5, 2.5, 0, "monster_soldier", 0.0, patrol=[[4.5, 2.5], [float(rx) - 1.5, 2.5]]);
        build.breakable(float(rx - 4), float(side - 3), 0.0, float(rx - 2), float(side - 1), 2.0, 30);
        rack_guard = build.waiting();
        build.touch(float(rx - self.rack), float(cy - 1), 0.0, float(rx), float(cy + 1), 6.0) +>:Fires:+> rack_guard;
        build.foe(float(self.long) - 2.5, float(cy) - 2.0, self.rack, mine3_foe(dice, self.danger), 180.0, waits=rack_guard);
        sparking(build, float(self.long) - 1.1, float(cy) + 2.5, float(self.rack) + 2.0, 2, 4.0);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a hall with the drill on its bed against a rock face
that its control sets cutting through to the way out."""
node DrillBreak(Prefab) {
    has key: str = "",
        tall: int = 14,
        drop: int = 4;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Drill break" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = MINE3;
        self.district = level_district(MINE3);
        self.long = dice.between(33, 35);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(13, 15);
        self.drop = dice.between(3, 5);
        self.low = -self.drop - 1;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        wall = 8;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, -self.drop, self.tall, self.key);
        rw = self.long - 11;
        build.level(room, -self.drop);
        build.solid(wall + 1, 1, -self.drop, rw, self.wide - 1, 0);
        # The rock face across the hall, the passage through it the drill
        # cuts; the way out beyond, down a few steps.
        build.solid(rw, 1, -self.drop, rw + 2, self.wide - 1, self.tall);
        build.widen(room, rw, cy - 2, 0, rw + 2, cy + 2, 8);
        cut = build.opened(float(rw), float(cy - 2), 0.0, float(rw + 2), float(cy + 2), 8.0);
        build.solid(rw + 2, 1, -self.drop, rw + 3, self.wide - 1, 0);
        stair(build, rw + 3 + self.drop - 1, cy - 2, -self.drop, 2, self.drop, 4);
        build.way_out(float(self.long) - 2.5, float(cy), -self.drop);
        # The drill on its bed along the south wall, riding back and forth.
        build.solid(wall + 2, 1, 0, rw, 4, 2);
        cart(build, [[float(wall + 3), 1.0, 2.0], [float(rw - 4), 1.0, 2.0]], 40.0, 1.0);
        # The control on a pulpit by the north wall.
        build.solid(wall + 2, self.wide - 5, 0, wall + 6, self.wide - 1, 4);
        stair(build, wall + 9, self.wide - 4, 0, 2, 4, 3);
        if self.key {
            build.solid(wall + 6, self.wide - 5, 0, wall + 10, self.wide - 4, 6);
            build.rising_door(float(wall + 10), float(self.wide - 5), 0.0, float(wall + 11), float(self.wide - 1), 6.0, {"key": self.key, "wait": "-1"});
        }
        control = build.push(float(wall) + 3.5, float(self.wide - 1), 5.0, 3);
        charges(build, control, [[float(rw) - 0.5, float(cy) - 4.0, 5.0], [float(rw) - 0.5, float(cy) + 4.0, 3.0], [float(rw) - 0.5, float(cy), 7.0]], 0.6);
        late = build.delay(2.5);
        control +>:Fires:+> late;
        late +>:Fires:+> cut;
        late +>:Fires:+> build.objective("New passage to lower mines created.");
        build.touch(float(rw - 3), float(cy - 2), 0.0, float(rw), float(cy + 2), 6.0, True, "Start the drill from its control.");
        beyond = build.waiting();
        late +>:Fires:+> beyond;
        build.foe(float(self.long) - 3.5, float(cy) + 3.5, -self.drop, mine3_foe(dice, self.danger, True), 180.0, waits=beyond);
        come_in = build.touch(float(wall + 1), float(cy - 2), 0.0, float(wall + 3), float(cy + 2), 6.0);
        hall_guard = build.waiting();
        come_in +>:Fires:+> hall_guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(rw) - 3.5, float(cy + 3 + index * 2) + 0.5, 0, mine3_foe(dice, self.danger), 180.0, waits=hall_guard);
        }
        build.foe(float(rw) - 6.5, float(cy) - 3.0, 0, "monster_gunner", 90.0, patrol=[[float(rw) - 6.5, float(cy) - 3.0], [float(rw) - 6.5, float(cy) + 3.0]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, mine3_foe(dice, self.danger), 180.0);
        }
        sparking(build, float(wall) + 6.2, float(self.wide) - 3.0, 5.5, 0, 3.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""mine3's stretches: [name, role]."""
glob MINE3_STRETCHES: list[list[str]] = [
         ["platform", "start"],
         ["bridge", "flow"],
         ["shaft", "flow"],
         ["charges", "hub"],
         ["rig", "hub"],
         ["samples", "keyroom"],
         ["drill", "end"],
         ["drill", "gate"]
     ];

"""One of mine3's stretches by its name."""
def make_mine3(name: str, key: str) -> Prefab {
    if name == "platform" {
        return DrillPlatform();
    }
    if name == "bridge" {
        return AccessBridge();
    }
    if name == "shaft" {
        return ServiceShaft();
    }
    if name == "charges" {
        return ChargeChamber();
    }
    if name == "rig" {
        return DrillRig();
    }
    if name == "samples" {
        return CoreSamples(key=key if key else "key_silver");
    }
    return DrillBreak(key=key);
}
