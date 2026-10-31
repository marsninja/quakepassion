"""Prefabs drawn from Quake II's mintro, the Mine Entrance: a road along a
cliff over a ravine to the barred factory gate, a yard of pipes and a
loading dock, a quarry pit with a stair down its walls, a chasm crossed
by a bridge that slides out when its switch is shot, a tall cavern the
hovers come out of, the foreman's shack, the mine's lift. Raised in
mintro's own palette.

- `CliffRoad`: the start. A road along a cliff, a ravine under it, a
  shelf high along the far wall and a rock arch from the shelf back over
  the road; ways on from the ravine's floor, the arch's end and the
  shelf. The help computer gives the objective; the factory's gate is
  barred ("Main factory door impassable"), and flyers come over the
  ravine as the player reaches it; berserkers wake as the player comes
  down into the ravine; a panel in the cliff under the road breaks open on
  a stash (the secret). Down by a stair or a lift; the arch west of the
  ramp or over its foot.
- `PipeYard`: a works yard under the sky, a flooded sump in its floor: a
  loading dock over a bay at its far end, a
  catwalk along its side over the floor, a pump house under the catwalk
  whose broken pipe sparks, and a panel on it that breaks open on a stash
  (mintro's sparking pipe, its secret). Up by a stair before the dock or
  at the yard's near end, and a steam vent that throws a body up; the
  berserkers in the bay come out as the player walks in, a guard walks
  the catwalk. Ways on from the floor, the dock and the catwalk (a hub).
- `QuarryPit`: a pit under the sky, a rim round it, a bridge of rock
  across it at the rim, a stair down its wall (or a lift and a stair);
  guards walk round its floor, more come up out of it as the player
  crosses the bridge, and a charge-filled wall at its foot blows open on
  a store. Ways on from the rim and from a tunnel at its floor (a hub).
- `SlideBridge`: a chasm over lava (or slime), a
  switch on its far wall that, shot, slides a bridge out a span at a time
  (mintro's bridge of four doors fired by a shot button), a gallery along
  its side over the drop.
- `HoverCavern`: a tall cavern entered high: a ledge, a stair down along
  its wall to a middle ledge over the floor and a stair on down to the
  floor; hovers come out of the dark as the player steps in, and a mutant
  is sent in when the player reaches the floor (a teleported ambush).
  A bridge of rock across at the top (or not); ways on from each height.
- `ForemanShack`: the key in a shack on a ledge, up a stair, a lift, or
  steps that rise when a switch is pressed; a catwalk along the wall over
  the floor; taking the key opens the closets below.
- `MineElevator`: the end. A door (a key's, as a gate), a room before the
  mine's shaft, the way out at its foot: down a lift cage, or a stair
  round the shaft's walls; charges go off as the player starts down."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, boulders, key_ambush, gate_into, lift, spiral, ring_path }
import from .minefact { slab, hurt, burning, sparking, stash, charges }

glob MINTRO: str = "q2:mintro";

"""mintro's foes: soldiers and berserkers, flyers and hovers, a mutant
deeper in."""
def mintro_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_hover" if dice.chance(0.3 + 0.4 * danger) else "monster_flyer";
    }
    return q1_foe(dice, q1_palette(["monster_berserk", "monster_soldier_ss"] if heavy else ["monster_soldier_light", "monster_soldier_light", "monster_berserk"], ["monster_mutant"] if heavy else ["monster_berserk"], danger * 0.6 if heavy else danger));
}

"""The start: a road along a cliff over a ravine to the barred factory
gate, a shelf along the far wall, an arch from it back over the road."""
node CliffRoad(Prefab) {
    has road: int = 7,
        shelf: int = 4,
        deep: int = 8,
        up: int = 7,
        arch_x: int = 6,
        by_lift: bool = False,
        stream: bool = True,
        tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cliff road";
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.long = dice.between(32, 36);
        self.wide = dice.between(26, 29);
        self.deep = dice.between(7, 9);
        self.up = dice.between(6, 8);
        self.tall = self.up + dice.between(30, 38);
        self.by_lift = dice.chance(0.4);
        self.stream = True;
        steps = self.up + self.deep;
        # The arch: west of the ramp up to the shelf, or over the ramp's
        # foot (high enough over it to walk under).
        west_most = self.long - 9 - steps;
        east_least = self.long + 3 - self.deep - self.up;
        if west_most >= 6 and dice.chance(0.5) {
            self.arch_x = dice.between(6, west_most);
        } else {
            self.arch_x = dice.between(east_least, self.long - 10);
        }
        self.low = -self.deep - 7;
        self.high = self.tall + 1;
        brink_y = 1 + self.road;
        rim = self.wide - 1 - self.shelf;
        self.enter = Port(face=2, along=float(1 + self.road // 2) + 0.5, floor=0);
        self.leaves = [
            Port(face=0, along=float((brink_y + rim) // 2), floor=-self.deep),
            Port(face=3, along=float(self.arch_x + 2), floor=self.up),
            Port(face=1, along=float(dice.between(5, self.long // 2)), floor=self.up)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        kit = kit_of(build.district);
        brink_y = 1 + self.road;
        rim = self.wide - 1 - self.shelf;
        low = -self.deep;
        steps = self.up + self.deep;
        ravine = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(ravine, 0);
        build.level(ravine, self.up);
        # The road on the cliff, the shelf along the far wall, the arch from
        # the shelf back over the ravine and the road.
        build.solid(1, 1, low, self.long - 1, brink_y, 0);
        build.solid(1, rim, low, self.long - 1, self.wide - 1, self.up);
        slab(build, self.arch_x, 1, self.arch_x + 4, rim, self.up, 1);
        # The factory's gate across the road's far end, barred.
        build.solid(self.long - 3, 1, 0, self.long - 1, brink_y, self.tall);
        build.put_box({"classname": "func_wall"}, float(self.long) - 3.25, 2.0, 0.0, float(self.long) - 3.0, float(brink_y - 1), 9.0, kit.door);
        # Down into the ravine at the gate's end: a stair along the cliff,
        # or a lift.
        if self.by_lift {
            lift(build, self.long - 5, brink_y, self.long - 2, brink_y + 3, low, 0);
            for x in range(self.long - 5, self.long - 2) {
                build.keep(ravine, x, brink_y - 1, 0);
            }
        } else {
            stair(build, self.long - 5, brink_y, low, 2, self.deep, 3);
            top = self.long - 4 - self.deep;
            for x in range(top - 1, top + 2) {
                build.keep(ravine, x, brink_y - 1, 0);
            }
        }
        # The ramp up the shelf's face from the ravine's floor.
        stair(build, self.long - 5, rim - 3, low, 2, steps, 3);
        ramp_top = self.long - 4 - steps;
        for x in range(ramp_top - 1, ramp_top + 2) {
            build.keep(ravine, x, rim, self.up);
        }
        build.doorway(ravine, self.enter);
        for port in self.taken {
            build.doorway(ravine, port);
        }
        # The stream down the ravine's middle, sunk in its floor, steps out
        # along its near side.
        if self.stream {
            build.pool(3, brink_y + 3, low - 5, self.long - 9 - self.deep, rim - 3, low, 2);
        }
        # The stash under the road, behind a panel in the cliff.
        sx = dice.between(3, 8);
        stash(build, sx, brink_y - 3, low, 1, Q2_ARMOR);
        middle = (brink_y + rim) // 2;
        clear = [[sx - 1, brink_y, sx + 3, brink_y + 3], [self.long - 7 - self.deep, brink_y, self.long - 1, brink_y + 4], [ramp_top - 1, rim - 4, self.long - 1, rim], [self.long - 5, middle - 3, self.long, middle + 3]];
        boulders(build, dice, 1, brink_y, self.long - 1, rim, low, dice.between(4, 7), clear);
        mid = float(1 + self.road // 2) + 0.5;
        build.start(2.5, mid, 0, 0.0);
        build.supply(2.5, mid - 2.0, 0, "ammo_shells", "q2");
        build.touch(1.0, 1.0, 0.0, 5.0, float(brink_y), 8.0) +>:Fires:+> build.objective("Navigate the mines. Find the mine entrance.");
        # The barred gate: flyers come over the ravine as the player reaches
        # it; its broken lamp sparks.
        barred = build.touch(float(self.long - 8), 1.0, 0.0, float(self.long - 3), float(brink_y), 8.0, True, "Main factory door impassable.");
        flyers = build.waiting();
        barred +>:Fires:+> flyers;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long - 10 - index * 5) + 0.5, float(middle) + 0.5, self.up + 3, mintro_foe(dice, self.danger, False, True), 180.0, waits=flyers);
        }
        sparking(build, float(self.long) - 3.1, float(brink_y) - 1.5, 6.0, 2, 5.0);
        # Berserkers wake as the player comes down into the ravine.
        down = build.touch(float(self.long - 5), float(brink_y), float(low), float(self.long - 1), float(rim), float(low + 6));
        pack = build.waiting();
        down +>:Fires:+> pack;
        for index in range(dice.between(1, 2)) {
            build.foe(float(10 + index * 4) + 0.5, float(middle) + 0.5, low, mintro_foe(dice, self.danger), 0.0, waits=pack);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + index * 3) + 0.5, float(brink_y) + 4.5, low, mintro_foe(dice, self.danger, index == 0), 180.0);
        }
        # A guard walks the shelf; another watches the road.
        shelf_y = float(rim) + float(self.shelf) * 0.5;
        build.foe(4.5, shelf_y, self.up, "monster_soldier_light", 0.0, patrol=[[4.5, shelf_y], [float(self.long) - 4.5, shelf_y]]);
        build.foe(float(self.long // 2) + 0.5, mid, 0, mintro_foe(dice, self.danger), 180.0);
        build.supply(float(self.long) - 6.5, shelf_y, self.up, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, low, "ammo_bullets", "q2");
    }
}

"""A works yard: a loading dock over a bay, a catwalk along its side, a
pump house under the catwalk whose broken pipe sparks."""
node PipeYard(Prefab) {
    has dock: int = 6,
        up: int = 9,
        walk: int = 4,
        house_x: int = 8,
        stair_west: bool = False,
        vent: bool = True,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pipe yard";
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.long = dice.between(26, 30);
        self.wide = dice.between(22, 24);
        self.dock = dice.between(6, 7);
        self.up = 9;
        self.walk = 4;
        self.tall = self.up + dice.between(26, 34);
        self.stair_west = dice.chance(0.5);
        self.vent = dice.chance(0.6);
        self.house_x = dice.between(self.long // 2 - 4, self.long // 2);
        self.low = -6;
        self.high = self.tall + 1;
        rim = self.wide - 1 - self.walk;
        front = self.long - 1 - self.dock;
        # Clear of the west stair (when there) along the near wall.
        self.enter = Port(face=2, along=float(dice.between(3, rim - self.up - 3)) if self.stair_west else float(dice.between(4, rim - 4)), floor=0);
        self.leaves = [
            Port(face=0, along=float(dice.between(4, self.wide - 5)), floor=self.up),
            Port(face=3, along=float(dice.between(5, front - 5)), floor=0),
            Port(face=1, along=float(dice.between(4, front - 4)), floor=self.up),
            Port(face=3, along=float(front + self.dock // 2), floor=self.up)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        rim = self.wide - 1 - self.walk;
        front = self.long - 1 - self.dock;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, self.up);
        # A flooded sump across the yard's floor, walked round.
        build.pool(6, 4, -4, front - 4, rim - 4, 0, 2);
        # The dock over its bay, pillars along its front; the catwalk along
        # the side wall at the dock's height.
        slab(build, front, 1, self.long - 1, self.wide - 1, self.up, 1);
        slab(build, 1, rim, front, self.wide - 1, self.up, 1);
        stair_band = [2, self.up + 2] if not self.stair_west else [0, 0];
        for y in range(4, rim - 1, 4) {
            if y + 1 < stair_band[0] or y > stair_band[1] {
                build.solid(front, y, 0, front + 1, y + 1, self.up - 1);
            }
        }
        # Up: a stair before the dock, or at the near end to the catwalk.
        if self.stair_west {
            stair(build, 1, rim - self.up, 0, 1, self.up, 3);
        } else {
            stair(build, front - 3, 2, 0, 1, self.up, 3);
            for y in range(self.up - 1, self.up + 3) {
                build.keep(yard, front, y, self.up);
            }
        }
        # The pump house under the catwalk, a stash behind a panel on it.
        hx = self.house_x;
        build.solid(hx, rim, 0, hx + 4, self.wide - 1, self.up - 1);
        panel = stash(build, hx + 1, rim + 1, 0, 3, "ammo_grenades");
        # Its pipe sparks; the panel's breaking throws more.
        sparking(build, float(hx) + 3.5, float(rim) - 0.1, 5.0, 3, 4.0);
        panel +>:Fires:+> build.sparks(float(hx) + 1.5, float(rim) - 0.1, 3.0, 3);
        # The steam vent: a jump pad three cells back from the catwalk's
        # brink_y, throwing a body up onto it.
        if self.vent {
            vx = hx - 4;
            build.jump_pad(float(vx) + 0.5, float(rim) - 2.5, 0, float(vx) + 0.5, float(rim) + 2.0, self.up);
            for x in range(vx - 1, vx + 2) {
                build.keep(yard, x, rim, self.up);
            }
            sparking(build, float(vx) + 0.5, float(rim) - 2.5, 0.5, 1, 3.0);
        }
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        # The berserkers in the bay come out as the player walks in.
        walk_in = build.touch(2.0, 2.0, 0.0, 6.0, float(rim - 1), 8.0);
        bay = build.waiting();
        walk_in +>:Fires:+> bay;
        for index in range(dice.between(2, 3)) {
            build.foe(float(front) + 2.5, float(5 + index * 4) + 0.5, 0, "monster_berserk" if index == 0 else mintro_foe(dice, self.danger), 180.0, waits=bay);
        }
        walk_y = float(rim) + 2.0;
        build.foe(3.5, walk_y, self.up, "monster_soldier_light", 0.0, patrol=[[3.5, walk_y], [float(front) - 1.5, walk_y], [float(front) + 2.5, float(rim) - 3.0]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5, float(4 + index * 6) + 0.5, self.up, mintro_foe(dice, self.danger, index == 1), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(rim // 2) + 0.5, 0, mintro_foe(dice, self.danger), 90.0);
        if dice.chance(0.5) {
            build.foe(float(self.long // 2) + 0.5, float(rim // 2) + 0.5, self.up + 4, mintro_foe(dice, self.danger, False, True), 180.0);
        }
        build.supply(float(self.long) - 3.5, float(self.wide) - 3.5, self.up, Q2_ARMOR, "q2");
        build.supply(float(front) + 3.5, float(rim) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(2.5, 2.5, 0, "ammo_shells", "q2");
    }
}

"""A pit under the sky, a rim round it, a bridge of rock across it, a
stair down its wall; a tunnel out of its floor."""
node QuarryPit(Prefab) {
    has deep: int = 10,
        tall: int = 12,
        spiral_start: int = 0,
        by_lift: bool = False,
        pond: bool = True,
        bridge_y: int = 12;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Quarry pit";
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.long = dice.between(28, 32);
        self.wide = dice.between(26, 30);
        self.deep = dice.between(10, 12);
        self.tall = dice.between(26, 32);
        self.by_lift = dice.chance(0.35);
        # The stair's first step along the pit's south wall, so it lands on
        # that wall short of the corner.
        seg = (self.long - 10) - 3;
        self.spiral_start = dice.between(0, max(0, seg - self.deep - 4));
        self.bridge_y = dice.between(self.wide // 2 - 2, self.wide // 2 + 1);
        self.pond = True;
        self.low = -self.deep - 7;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(dice.between(6, self.wide - 7)), floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=0),
            Port(face=0, along=float(cy), floor=-self.deep),
            Port(face=3, along=float(dice.between(6, self.long - 7)), floor=0),
            Port(face=0, along=float(self.wide - 3), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.deep;
        px0 = 5;
        py0 = 5;
        px1 = self.long - 5;
        py1 = self.wide - 5;
        cy = self.wide // 2;
        quarry = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(quarry, 0);
        # The rim round the pit.
        build.solid(1, 1, low, self.long - 1, py0, 0);
        build.solid(1, py1, low, self.long - 1, self.wide - 1, 0);
        build.solid(1, py0, low, px0, py1, 0);
        build.solid(px1, py0, low, self.long - 1, py1, 0);
        # The bridge of rock across at the rim.
        span_y = self.bridge_y;
        slab(build, px0, span_y, px1, span_y + 4, 0, 2);
        # Down: a stair along the south wall, or a lift in its corner and a
        # stair along the west wall.
        if self.by_lift {
            lift(build, px1 - 3, py0, px1, py0 + 3, low, 0);
            for x in range(px1 - 3, px1) {
                build.keep(quarry, x, py0 - 1, 0);
            }
            stair(build, px0, py0 + self.deep - 1, low, 3, self.deep, 3);
            for x in range(px0, px0 + 3) {
                build.keep(quarry, x, py0 - 1, 0);
            }
        } else {
            spiral(build, px0, py0, px1, py1, low, self.deep, 3, 3, self.spiral_start);
            for x in range(px0 + self.spiral_start + self.deep - 2, px0 + self.spiral_start + self.deep + 3) {
                build.keep(quarry, x, py0 - 1, 0);
            }
        }
        # A pond in the pit's floor under the bridge, steps out of it.
        if self.pond {
            build.pool(self.long // 2 - 6, py0 + 5, low - 5, self.long // 2 + 6, py1 - 3, low, 2);
        }
        # The tunnel out of the pit's floor, under the east rim.
        build.widen(quarry, px1, cy - 2, low, self.long - 1, cy + 2, low + 8);
        build.doorway(quarry, self.enter);
        for port in self.taken {
            build.doorway(quarry, port);
        }
        # A store in the north wall at the floor, behind a wall packed with
        # charges that blows open when shot.
        ex = dice.between(px0 + 4, px1 - 8);
        store = build.room(ex, py1 + 1, low, ex + 4, py1 + 3, low + 5);
        build.widen(store, ex, py1, low, ex + 4, py1 + 1, low + 5);
        blast = build.breakable(float(ex), float(py1), float(low), float(ex + 4), float(py1 + 1), float(low + 5), 60);
        charges(build, blast, [[float(ex) + 1.0, float(py1) - 0.5, float(low + 2)], [float(ex) + 3.0, float(py1) - 1.5, float(low + 1)]], 0.25);
        build.supply(float(ex) + 1.0, float(py1) + 2.0, low, "ammo_grenades", "q2");
        build.supply(float(ex) + 3.0, float(py1) + 2.0, low, Q2_HEALTH, "q2");
        # Guards walk round the pit's floor; more come up out of it as the
        # player crosses the bridge.
        ring = [[float(px0) + 4.5, float(py0) + 4.5], [float(px1) - 4.5, float(py0) + 4.5], [float(px1) - 4.5, float(py1) - 2.5], [float(px0) + 4.5, float(py1) - 2.5]];
        build.foe(float(px0) + 4.5, float(py0) + 4.5, low, "monster_soldier_light", 0.0, patrol=ring);
        if dice.chance(0.6) {
            build.foe(float(px1) - 4.5, float(py1) - 2.5, low, "monster_soldier_light", 180.0, patrol=[ring[2], ring[3], ring[0], ring[1]]);
        }
        crossing = build.touch(float(self.long // 2 - 1), float(span_y), 0.0, float(self.long // 2 + 1), float(span_y + 4), 6.0);
        below = build.waiting();
        crossing +>:Fires:+> below;
        for index in range(dice.between(2, 3)) {
            build.foe(float(px0 + 3 + index * 4) + 0.5, float(py1) - 1.5, low, mintro_foe(dice, self.danger, index == 0), 270.0, waits=below);
        }
        build.foe(float(self.long) - 3.0, float(cy) + 0.5, low, mintro_foe(dice, self.danger, True), 180.0, waits=below);
        for index in range(dice.between(2, 3)) {
            build.foe(float(3 + index * 9) + 0.5, float(self.wide) - 3.0, 0, mintro_foe(dice, self.danger), 270.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(cy) + 0.5, 6, mintro_foe(dice, self.danger, False, True), 180.0);
        sparking(build, 1.1, 2.5, 3.0, 0, 6.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long // 2) + 0.5, float(span_y) + 2.0, 0, "ammo_bullets", "q2");
    }
}

"""A chasm, a switch on its far wall that, shot, slides a bridge out a
span at a time; a gallery along its side."""
node SlideBridge(Prefab) {
    has near: int = 7,
        spans: int = 4,
        far: int = 3,
        deep: int = 9,
        gallery: int = 6,
        lava: bool = True,
        low_switch: bool = True,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slide bridge";
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.spans = dice.between(3, 4);
        self.near = dice.between(7, 8);
        self.far = 3;
        self.long = 1 + self.near + self.spans * 3 + self.far + 1;
        self.wide = dice.between(14, 16);
        self.deep = dice.between(8, 10);
        self.gallery = dice.between(6, 7);
        self.lava = dice.chance(0.6);
        self.low_switch = dice.chance(0.5);
        self.tall = self.gallery + dice.between(22, 30);
        self.low = -2 * self.deep - 4;
        self.high = self.tall + 1;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(dice.between(3, self.wide - 8)), floor=0);
        self.leaves = [Port(face=0, along=float(cy), floor=0)];
        if dice.chance(0.4) {
            self.leaves.append(Port(face=1, along=float(1 + self.near + 3), floor=self.gallery));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.deep;
        cy = self.wide // 2;
        x0 = 1 + self.near;
        x1 = self.long - 1 - self.far;
        chasm = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(chasm, 0);
        build.level(chasm, self.gallery);
        build.solid(1, 1, low, x0, self.wide - 1, 0);
        build.solid(x1, 1, low, self.long - 1, self.wide - 1, 0);
        burning(build, x0, 1, low, x1, self.wide - 1, low + 3, 4 if self.lava else 3, 20 if self.lava else 8);
        # The gallery along the side over the drop, a stair up to it on the
        # near ledge.
        gy = self.wide - 4;
        slab(build, x0, gy, x1 - 4, self.wide - 1, self.gallery, 2);
        stair(build, x0 - self.gallery, gy, 0, 0, self.gallery, 3);
        for y in range(gy, self.wide - 1) {
            build.keep(chasm, x0 - 1, y, self.gallery);
        }
        build.doorway(chasm, self.enter);
        for port in self.taken {
            build.doorway(chasm, port);
        }
        for y in range(cy - 2, cy + 2) {
            build.keep(chasm, x0 - 1, y, 0);
            build.keep(chasm, x1, y, 0);
        }
        # The switch on the far wall: shot, the bridge slides out a span at
        # a time.
        trip = build.push(float(self.long - 1), float(cy) + 3.5, 2.0 if self.low_switch else 9.0, 2, True);
        for index in range(self.spans) {
            late = build.delay(0.5 * float(index));
            trip +>:Fires:+> late;
            late +>:Fires:+> build.drawn(float(x0 + index * 3), float(cy - 2), float(x0 + index * 3 + 3), float(cy + 2), 0, self.deep + 1);
        }
        # Crates of charges in the near ledge's corner, that blow when shot.
        crate = build.breakable(float(x0 - 3), 1.0, 0.0, float(x0 - 1), 3.0, 2.0, 40);
        charges(build, crate, [[float(x0) - 2.0, 2.0, 1.0]], 0.0);
        # At the ledge's brink_y, guards appear on the far side and the gallery.
        brink = build.touch(float(x0 - 3), float(cy - 3), 0.0, float(x0), float(cy + 3), 6.0);
        far_side = build.waiting();
        brink +>:Fires:+> far_side;
        for index in range(dice.between(1, 2)) {
            build.foe(float(x1) + 1.5, float(cy) + (2.5 if index == 0 else -3.5), 0, mintro_foe(dice, self.danger), 180.0, waits=far_side);
        }
        build.foe(float(x1) - 6.5, float(gy) + 1.5, self.gallery, mintro_foe(dice, self.danger, True), 180.0, waits=far_side);
        gallery_y = float(gy) + 1.5;
        build.foe(float(x0) + 1.5, gallery_y, self.gallery, "monster_soldier_light", 0.0, patrol=[[float(x0) + 1.5, gallery_y], [float(x1) - 5.5, gallery_y]]);
        build.foe(float(x0 + x1) * 0.5, float(cy) + 0.5, 5, mintro_foe(dice, self.danger, False, True), 180.0);
        build.supply(2.5, float(self.wide) - 6.5, 0, Q2_HEALTH, "q2");
        build.supply(float(x1 - 5) + 0.5, float(gy) + 1.5, self.gallery, "ammo_bullets", "q2");
    }
}

"""A tall cavern entered high: a stair down its wall to a middle ledge,
a stair on down to its floor; a bridge of rock across at the top."""
node HoverCavern(Prefab) {
    has drop: int = 15,
        mid: int = 8,
        top: int = 9,
        bridge: bool = True,
        lake: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Hover cavern";
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.drop = dice.between(14, 16);
        self.mid = self.drop // 2;
        self.long = dice.between(self.mid + 17, self.mid + 20);
        self.wide = dice.between(self.drop - self.mid + 15, self.drop - self.mid + 18);
        self.top = dice.between(16, 22);
        self.bridge = dice.chance(0.6);
        self.lake = True;
        self.low = -self.drop - 7;
        self.high = self.top + 26;
        cy = self.wide // 2;
        self.enter = Port(face=2, along=float(cy), floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide - 4), floor=-self.drop),
            Port(face=3, along=float(dice.between(9 + self.mid, self.long - 5)), floor=-self.mid),
            Port(face=1, along=float(dice.between(9, self.long - 6)), floor=-self.drop)
        ];
        if self.bridge {
            self.leaves.append(Port(face=0, along=float(self.wide - 4), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = -self.drop;
        cy = self.wide // 2;
        cave = build.room(1, 1, low, self.long - 1, self.wide - 1, self.top, variant=dice.below(3));
        build.level(cave, 0);
        build.level(cave, -self.mid);
        build.level(cave, low);
        # The entry ledge, the stair down the south wall to the middle
        # ledge, the stair on down the east wall to the floor.
        slab(build, 1, 1, 7, self.wide - 1, 0, 2);
        stair(build, 6 + self.mid, 1, -self.mid, 2, self.mid, 3);
        slab(build, 7 + self.mid, 1, self.long - 1, 8, -self.mid, 2);
        stair(build, self.long - 4, 7 + self.drop - self.mid, low, 3, self.drop - self.mid, 3);
        if self.bridge {
            slab(build, 7, self.wide - 6, self.long - 1, self.wide - 2, 0, 2);
        }
        # A pool in the floor's south half.
        if self.lake {
            build.pool(9, 5, low - 5, self.long - 7, self.wide - 7, low, 2);
        }
        # A rock pillar under the entry ledge, a foe sealed in it.
        build.solid(1, self.wide - 5, low, 5, self.wide - 1, low + 8);
        # The drop off the entry ledge, kept clear of railings.
        for y in range(cy - 1, cy + 2) {
            build.keep(cave, 6, y, 0);
        }
        build.doorway(cave, self.enter);
        for port in self.taken {
            build.doorway(cave, port);
        }
        # Hovers come out of the dark as the player steps in.
        step_in = build.touch(1.0, float(cy - 2), 0.0, 4.0, float(cy + 2), 6.0);
        dark = build.waiting();
        step_in +>:Fires:+> dark;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 + index * 3) + 0.5, float(cy + index * 2 - 2) + 0.5, -self.mid + 2, mintro_foe(dice, self.danger, False, True), 180.0, waits=dark);
        }
        # At the foot of the stair a mutant is sent in.
        foot = build.touch(float(self.long - 4), float(8 + self.drop - self.mid), float(low), float(self.long - 1), float(11 + self.drop - self.mid), float(low + 6));
        foot +>:Fires:+> build.summon(1, self.wide - 4, low, "monster_mutant" if self.danger > 0.3 else "monster_berserk", float(self.long // 2) + 0.5, float(self.wide) - 4.5, low, 0.0);
        build.foe(9.5, float(self.wide) - 3.5, low, "monster_berserk", 0.0, patrol=[[9.5, float(self.wide) - 3.5], [float(self.long) - 6.5, float(self.wide) - 3.5]]);
        build.foe(float(self.long) - 3.5, 4.5, -self.mid, mintro_foe(dice, self.danger), 180.0);
        if self.bridge {
            build.foe(float(self.long) - 3.5, float(self.wide) - 4.0, 0, mintro_foe(dice, self.danger), 180.0);
        }
        build.supply(float(self.long) - 6.5, 3.5, -self.mid, Q2_HEALTH, "q2");
        build.supply(9.5, 3.5, low, "ammo_bullets", "q2");
        build.supply(3.5, float(cy) + 3.5, 0, "ammo_shells", "q2");
    }
}

"""The key in a shack on a ledge, up a stair, a lift or steps a switch
raises; a catwalk along the wall over the floor."""
node ForemanShack(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        ledge: int = 6,
        way_up: int = 0,
        tall: int = 15;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Foreman shack (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.long = dice.between(22, 24);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.ledge = dice.between(6, 7);
        self.way_up = dice.below(3);
        self.tall = self.ledge + 9;
        self.low = -self.ledge - 1;
        self.high = self.tall + 28;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        cave = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(cave, self.ledge);
        build.doorway(cave, self.enter);
        lx = self.long - 7;
        build.solid(lx, 1, 0, self.long - 1, side, self.ledge);
        # The catwalk along the south wall, over the floor, to the ledge.
        slab(build, 4, 1, lx, 4, self.ledge, 1);
        if self.way_up == 0 {
            stair(build, lx - self.ledge, cy, 0, 0, self.ledge, 3);
            for y in range(cy, cy + 3) {
                build.keep(cave, lx, y, self.ledge);
            }
        } elif self.way_up == 1 {
            lift(build, lx - 3, cy - 1, lx, cy + 2, 0, self.ledge);
            for y in range(cy - 1, cy + 2) {
                build.keep(cave, lx, y, self.ledge);
            }
        } else {
            # Steps that rise out of the floor when the switch by the way in
            # is pressed, up to the catwalk's near end.
            press = build.push(2.5, 1.0, 1.0, 1);
            press +>:Fires:+> build.rising_steps(4, 4 + self.ledge - 1, 0, 3, self.ledge, 3);
            for x in range(4, 7) {
                build.keep(cave, x, 4, self.ledge);
            }
        }
        # The shack: walls round the ledge's far half, a doorway in front.
        build.solid(lx + 2, cy - 4, self.ledge, lx + 3, cy - 1, self.ledge + 5);
        build.solid(lx + 2, cy + 2, self.ledge, lx + 3, cy + 5, self.ledge + 5);
        build.solid(lx + 2, cy - 4, self.ledge + 5, self.long - 1, cy + 5, self.ledge + 6);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.ledge, side, 0, [2, lx - 4], [mintro_foe(dice, self.danger, True), mintro_foe(dice, self.danger)]);
        sparking(build, float(lx) + 2.4, float(cy) - 2.5, float(self.ledge) + 3.0, 2, 5.0);
        # Stepping up onto the ledge wakes the foreman's guards.
        guard = build.waiting();
        build.touch(float(lx), float(cy - 3), float(self.ledge), float(lx + 2), float(cy + 4), float(self.ledge + 6)) +>:Fires:+> guard;
        build.foe(float(self.long) - 2.5, float(cy) - 3.0, self.ledge, mintro_foe(dice, self.danger), 180.0, waits=guard);
        build.foe(float(lx) + 1.0, 3.0, self.ledge, mintro_foe(dice, self.danger), 180.0);
        build.foe(5.5, 2.5, self.ledge, "monster_soldier_light", 0.0, patrol=[[5.5, 2.5], [float(lx) - 1.5, 2.5]]);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
        build.supply(float(lx) - 2.5, 2.5, self.ledge, "ammo_bullets", "q2");
    }
}

"""The end: a door, a room before the mine's shaft, the way out at its
foot, down a lift cage or a stair round its walls."""
node MineElevator(Prefab) {
    has key: str = "",
        shaft: int = 10,
        by_lift: bool = True,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Mine elevator" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.long = dice.between(26, 28);
        self.wide = dice.between(16, 18);
        self.shaft = dice.between(9, 11);
        self.by_lift = dice.chance(0.5);
        self.tall = dice.between(13, 15);
        self.low = -self.shaft - 1;
        self.high = self.tall + 28;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        wall = 8;
        low = -self.shaft;
        room = gate_into(build, dice, self.enter, self.long, self.wide, wall, low, self.tall, self.key);
        build.level(room, low);
        sx = wall + 6;
        # The floor before the shaft, the shaft down to the way out.
        build.solid(wall + 1, 1, low, sx, self.wide - 1, 0);
        if self.by_lift {
            build.solid(sx, 1, low, self.long - 1, middle - 3, 0);
            build.solid(sx, middle + 3, low, self.long - 1, self.wide - 1, 0);
            lift(build, sx, middle - 2, sx + 3, middle + 2, low, 0);
            for y in range(middle - 2, middle + 2) {
                build.keep(room, sx - 1, y, 0);
            }
            build.way_out(float(self.long) - 3.5, float(middle), low);
        } else {
            lap = len(ring_path(sx, 1, self.long - 1, self.wide - 1, 3));
            start = (lap - self.shaft - 3) % lap;
            spiral(build, sx, 1, self.long - 1, self.wide - 1, low, self.shaft, 3, 3, start);
            build.way_out(float(sx + self.long - 1) * 0.5, float(middle), low);
        }
        # A perch over the shaft's far end, its guard.
        slab(build, self.long - 4, 1, self.long - 1, self.wide - 1, 6, 1);
        build.foe(float(self.long) - 2.5, float(middle) + 0.5, 6, mintro_foe(dice, self.danger), 180.0);
        build.touch(float(wall + 1), float(middle - 2), 0.0, float(wall + 3), float(middle + 2), 6.0) +>:Fires:+> build.objective("Take the mine elevator down.");
        # Guards appear on the floor as the player comes through the door;
        # charges go off as the player reaches the shaft's foot.
        door_touch = build.touch(float(wall + 1), 1.0, 0.0, float(wall + 2), float(self.wide - 1), 6.0);
        floor_guard = build.waiting();
        door_touch +>:Fires:+> floor_guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(sx) - 2.0, 2.5 + float(index) * (float(self.wide) - 5.0), 0, mintro_foe(dice, self.danger), 180.0, waits=floor_guard);
        }
        start_down = build.touch(float(sx), 1.0, float(low), float(self.long - 1), float(self.wide - 1), float(low + 4));
        charges(build, start_down, [[float(self.long) - 1.5, float(middle) - 4.0, 4.0], [float(self.long) - 1.5, float(middle) + 4.0, 3.0]], 0.4);
        sparking(build, float(sx) + 0.5, 1.1, 3.0, 1, 4.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, mintro_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(sx) + 3.5, float(middle) + 0.5, low, mintro_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""mintro's stretches: [name, role]."""
glob MINTRO_STRETCHES: list[list[str]] = [
         ["road", "start"],
         ["yard", "flow"],
         ["bridge", "flow"],
         ["cavern", "flow"],
         ["quarry", "hub"],
         ["yard", "hub"],
         ["cavern", "hub"],
         ["shack", "keyroom"],
         ["lift", "end"],
         ["lift", "gate"]
     ];

"""One of mintro's stretches by its name."""
def make_mintro(name: str, key: str) -> Prefab {
    if name == "road" {
        return CliffRoad();
    }
    if name == "yard" {
        return PipeYard();
    }
    if name == "bridge" {
        return SlideBridge();
    }
    if name == "cavern" {
        return HoverCavern();
    }
    if name == "quarry" {
        return QuarryPit();
    }
    if name == "shack" {
        return ForemanShack(key=key if key else "key_silver");
    }
    return MineElevator(key=key);
}
