"""Prefabs drawn from e3m4, Satan's Dark Delight: dark halls over black
water, a pier across a flooded hall under galleries, steps that rise out
of the floor to a dais when a button is shot (e3m4's stair of doors), a
tower of lifts one over another, a great altar standing in a moat bridged
to from the walls, a crossing of black water on a platform set going, a
vault beyond a wall dived under. e3m4 holds no keys; its key room and
gate are drawn from its vaults. Raised in e3m4's own palette.

- `DarkPier`: the start. A hall over black water, a pier across it,
  galleries along both its long walls over the water ridden up to by a
  lift and joined at the far end; a dais at the far end climbed only by
  steps that rise out of the floor when a button on the far wall is shot.
- `ElevatorTower`: a tower of three lifts, each up to a ledge over the
  last, stumps of pillars at its foot; its top way on shut until a button is shot
  ("This door is opened elsewhere."); scrags wake as the player rides up.
- `DelightAltar`: a great altar standing in a moat, a causeway out to it
  and a lift up its face (or a teleporter onto it), bridges from its top
  over the water to ways on high in two walls, a walk round the moat (a
  hub). A button on the altar opens the north way on.
- `BlackCrossing`: a hall of black water, a platform at the near dock set
  riding over it as the player steps to the edge (e3m4's trains), the
  water swum in the meantime; a walkway high along the wall back from the
  far landing to drop from.
- `DivedVault`: the key room. A pool across a vault, a wall down into it
  to dive under, the key beyond on a dais; a gallery over the near half;
  taking the key opens the closets and brings fiends in.
- `DelightExit`: the end. A door (a key's, as a gate), a hall of pillars
  standing in water, a causeway to the dais of the slipgate, steps rising
  out of the floor to it when a button is shot; ogres on a gallery over
  the water."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from .roster { FoeMix }
import from .common { stair, pillars, lift, ring_path }
import from .e2m4 { e2m4_bars, e2m4_key, e2m4_moat, e2m4_stash, e2m4_closets }

glob E3M4: str = "q1:e3m4";

"""e3m4's foes: ogres above all, the dead and scrags, fiends deeper in."""
glob E3M4_FOES: FoeMix = FoeMix(light=["monster_ogre", "monster_zombie", "monster_wizard"], strong=["monster_ogre"], heavy_light=["monster_ogre", "monster_ogre"], heavy_strong=["monster_demon1"]);

"""The start: a hall over black water, a pier across it, galleries over it,
a dais at the far end up steps a shot button raises."""
node DarkPier(Prefab) {
    has deep: int = 7,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dark pier";
        self.source = E3M4;
        self.district = level_district(E3M4);
        self.long = dice.between(32, 36);
        self.wide = dice.between(20, 24);
        self.deep = dice.between(5, 6);
        self.low = -10;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=4), Port(face=0, along=3.0, floor=9), Port(face=3, along=float(self.long - 4), floor=0), Port(face=1, along=float(self.long - 4), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        d = self.deep;
        fx = self.long - 9;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 9);
        e2m4_moat(build, 6, fx, 1, self.wide - 1, d, 0, True);
        build.solid(6, middle - 1, -1, fx, middle + 2, 0);
        for y in range(middle - 1, middle + 2) {
            build.keep(hall, 5, y, 0);
            build.keep(hall, fx, y, 0);
        }
        # The galleries over the water along both long walls, joined across
        # the far landing; a lift up from the near landing.
        build.solid(1, 1, 8, self.long - 1, 5, 9);
        build.solid(1, self.wide - 5, 8, self.long - 1, self.wide - 1, 9);
        build.solid(fx, 5, 8, fx + 3, self.wide - 5, 9);
        lift(build, 2, 6, 5, 9, 0, 9);
        for x in range(2, 5) {
            build.keep(hall, x, 5, 9);
            build.keep(hall, x, 10, 0);
        }
        # The dais at the far end, climbed only by steps that rise out of
        # the floor when the button on the far wall is shot.
        build.solid(self.long - 5, middle - 3, 0, self.long - 1, middle + 3, 4);
        steps = build.rising_steps(fx, middle - 1, 0, 0, 4, 3);
        shot = build.push(float(self.long - 1), float(middle) + 4.5, 6.0, 2, True);
        shot +>:Fires:+> steps;
        for port in self.taken {
            build.doorway(hall, port);
            # The far landing's ways on below open with the steps.
            if port.floor == 0 {
                low = port.along - 2.0;
                if port.face == 3 {
                    shot +>:Fires:+> e2m4_bars(build, low, 1.0, low + 4.0, 2.0, 0, 8, "This door is opened elsewhere.");
                } else {
                    shot +>:Fires:+> e2m4_bars(build, low, float(self.wide - 2), low + 4.0, float(self.wide - 1), 0, 8, "This door is opened elsewhere.");
                }
            }
        }
        # Scrags brought in over the water as the player reaches the far
        # landing.
        across = build.touch(float(fx), 1.0, 0.0, float(fx + 2), float(self.wide - 1), 6.0);
        late = build.delay(0.5);
        across +>:Fires:+> late;
        for index in range(2) {
            late +>:Fires:+> build.summon(1, 2 + index * 9, -9, "monster_wizard", float(fx) - 6.5 - float(index) * 6.0, float(middle) + 3.5, 4, 180.0);
        }
        build.solid(1, self.wide - 6, 0, 6, self.wide - 1, 8);
        e2m4_stash(build, 2, self.wide - 4, 4, self.wide - 1, 0, 3, "item_artifact_super_damage");
        # The far landing's keepers wake as the player sets out on the pier.
        onto = build.touch(5.0, float(middle - 1), 0.0, 8.0, float(middle + 2), 6.0);
        guard = build.waiting();
        onto +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(fx) + 2.5, float(middle) - 5.5 + float(index) * 5.5, 0, E3M4_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        build.foe(7.5, 3.0, 9, "monster_ogre", 0.0, patrol=[[7.5, 3.0], [float(self.long) - 3.5, 3.0]]);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 5, "monster_wizard", 180.0);
        build.foe(12.5, float(middle) - 4.5, -d + 1, "monster_fish", 0.0);
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 4, "item_health");
        build.supply(float(self.long) - 2.5, 3.0, 9, "item_rockets");
    }
}

"""A tower of three lifts, each up to a ledge over the last."""
node ElevatorTower(Prefab) {
    has tall: int = 30;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Elevator tower";
        self.source = E3M4;
        self.district = level_district(E3M4);
        self.long = dice.between(17, 19);
        self.wide = dice.between(17, 19);
        self.low = -8;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=4.0, floor=0);
        self.leaves = [Port(face=3, along=float(self.long // 2), floor=21), Port(face=1, along=4.0, floor=7), Port(face=0, along=float(self.wide // 2), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        tower = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        for z in [7, 14, 21] {
            build.level(tower, z);
        }
        pillars(build, 7, 7, self.long - 7, self.wide - 7, 0, 6, 4, []);
        # The first ledge along the north wall, the second along the east
        # over the first's end, the third along the south over the second's.
        build.solid(1, self.wide - 6, 6, self.long - 1, self.wide - 1, 7);
        build.solid(self.long - 6, 1, 13, self.long - 1, self.wide - 1, 14);
        build.solid(1, 1, 20, self.long - 1, 6, 21);
        lift(build, 2, self.wide - 9, 5, self.wide - 6, 0, 7);
        lift(build, self.long - 9, self.wide - 5, self.long - 6, self.wide - 2, 7, 14);
        lift(build, self.long - 5, 7, self.long - 2, 10, 14, 21);
        for x in range(2, 5) {
            build.keep(tower, x, self.wide - 6, 7);
            build.keep(tower, x, self.wide - 10, 0);
        }
        for y in range(self.wide - 5, self.wide - 2) {
            build.keep(tower, self.long - 6, y, 14);
            build.keep(tower, self.long - 10, y, 7);
        }
        for x in range(self.long - 5, self.long - 2) {
            build.keep(tower, x, 6, 21);
            build.keep(tower, x, 11, 14);
        }
        # The top way on shut until a button high on the north wall is shot.
        shot = build.push(float(self.long // 2), float(self.wide - 1), 24.0, 3, True);
        build.doorway(tower, self.enter);
        for port in self.taken {
            build.doorway(tower, port);
            if port.floor == 21 {
                build.solid(int(port.along) - 2, 1, 13, int(port.along) + 2, 3, 20);
                shot +>:Fires:+> e2m4_bars(build, port.along - 2.0, 1.0, port.along + 2.0, 2.0, 21, 8, "This door is opened elsewhere.");
            }
        }
        # Scrags wake as the player rides the first lift; the top ledge's
        # keeper as the player comes onto it.
        ride = build.touch(2.0, float(self.wide - 9), 0.0, 5.0, float(self.wide - 6), 6.0);
        air = build.waiting();
        ride +>:Fires:+> air;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2) - 1.5 + float(index), float(self.wide // 2) - 1.5 + float(index), 8 + index * 5, "monster_wizard", float(index * 120), waits=air);
        }
        onto = build.touch(float(self.long - 5), 5.0, 21.0, float(self.long - 2), 7.0, 27.0);
        keeper = build.waiting();
        onto +>:Fires:+> keeper;
        build.foe(4.5, 3.5, 21, E3M4_FOES.pick(dice, self.danger, True), 0.0, waits=keeper);
        late = build.delay(1.0);
        onto +>:Fires:+> late;
        late +>:Fires:+> build.summon(7, 7, -7, E3M4_FOES.pick(dice, self.danger), float(self.long // 2) + 0.5, 3.5, 21, 0.0);
        build.foe(4.5, float(self.wide) - 3.0, 7, E3M4_FOES.pick(dice, self.danger), 0.0, patrol=[[4.5, float(self.wide) - 3.0], [float(self.long) - 11.5, float(self.wide) - 3.0]]);
        build.foe(float(self.long) - 3.5, 13.5, 14, E3M4_FOES.pick(dice, self.danger), 270.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 3.5, 14, "item_health");
        build.supply(float(self.long // 2) + 0.5, 3.5, 21, "item_rockets");
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""A great altar standing in a moat, a causeway and a lift to it, bridges
from its top to ways on high."""
node DelightAltar(Prefab) {
    has altar: int = 9,
        tele: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Delight altar";
        self.source = E3M4;
        self.district = level_district(E3M4);
        self.long = dice.between(30, 34);
        self.wide = dice.between(26, 30);
        self.tele = dice.chance(0.5);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.wide // 2), floor=self.altar), Port(face=1, along=float(self.long // 2), floor=self.altar), Port(face=3, along=float(self.long - 5), floor=0), Port(face=0, along=3.0, floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        a = self.altar;
        cx = self.long // 2;
        cy = self.wide // 2;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, a);
        # The moat, a walk round it, the altar standing in it, a causeway
        # out to it from the south walk and a lift up its face.
        e2m4_moat(build, 4, self.long - 4, 4, self.wide - 4, 5, 0, True);
        build.solid(cx - 4, cy - 4, -5, cx + 4, cy + 4, a);
        build.solid(cx - 1, 4, -1, cx + 2, cy - 4, 0);
        lift(build, cx - 1, cy - 7, cx + 2, cy - 4, 0, a);
        for x in range(cx - 1, cx + 2) {
            build.keep(hall, x, cy - 4, a);
        }
        if self.tele {
            build.teleporter(2.5, float(self.wide) - 2.5, 0, float(cx) + 0.5, float(cy) + 0.5, a, 0.0);
        }
        # The bridges from the altar's top over the water to the east and
        # north walls.
        build.solid(cx + 4, cy - 2, a - 1, self.long - 1, cy + 2, a);
        build.solid(cx - 2, cy + 4, a - 1, cx + 2, self.wide - 1, a);
        for y in range(cy - 2, cy + 2) {
            build.keep(hall, cx + 3, y, a);
        }
        for x in range(cx - 2, cx + 2) {
            build.keep(hall, x, cy + 3, a);
        }
        # A gallery round the walls at the bridges' height, over the walk
        # and the moat's edge.
        for cell in ring_path(1, 1, self.long - 1, self.wide - 1, 4) {
            build.solid(cell[0], cell[1], a - 1, cell[2], cell[3], a);
        }
        # A button on the altar opens the north way on.
        build.solid(cx - 3, cy + 2, a, cx - 2, cy + 3, a + 3);
        press = build.push(float(cx - 2), float(cy) + 2.5, float(a) + 1.2, 0);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.face == 1 and port.floor == a {
                build.solid(int(port.along) - 2, self.wide - 4, 0, int(port.along) + 2, self.wide - 1, a - 1);
                press +>:Fires:+> e2m4_bars(build, port.along - 2.0, float(self.wide - 2), port.along + 2.0, float(self.wide - 1), a, 8, "This door is opened elsewhere.");
            }
            if port.face == 0 and port.floor == a {
                build.solid(self.long - 4, int(port.along) - 2, 0, self.long - 1, int(port.along) + 2, a - 1);
                press +>:Fires:+> e2m4_bars(build, float(self.long - 2), port.along - 2.0, float(self.long - 1), port.along + 2.0, a, 8, "This door is opened elsewhere.");
            }
        }
        # What keeps the altar's top wakes as the player sets out on the
        # causeway; an ogre walks round the moat; scrags over the water.
        onto = build.touch(float(cx - 1), 4.0, 0.0, float(cx + 2), 6.0, 6.0);
        guard = build.waiting();
        onto +>:Fires:+> guard;
        late = build.delay(1.0);
        onto +>:Fires:+> late;
        for index in range(2) {
            late +>:Fires:+> build.summon(1, 6 + index * 5, -8, "monster_wizard" if index == 0 else E3M4_FOES.pick(dice, self.danger, True), float(cx) - 6.5 + float(index) * 13.0, float(cy) - 6.5, 3 if index == 0 else 0, 0.0);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(cx) - 2.5 + float(index) * 2.0, float(cy) + 1.5, a, E3M4_FOES.pick(dice, self.danger, index == 0), 270.0, waits=guard);
        }
        build.foe(2.5, 2.5, 0, "monster_ogre", 0.0, patrol=[[2.5, 2.5], [float(self.long) - 2.5, 2.5], [float(self.long) - 2.5, float(self.wide) - 6.5]]);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) - 8.5 + float(index) * 16.0, float(cy) + 0.5, 5, "monster_wizard", 180.0);
        }
        build.foe(8.5, 8.5, -4, "monster_fish", 0.0);
        build.supply(float(cx) + 2.5, float(cy) - 2.5, a, "item_health");
        # What keeps the gallery wakes as the player comes off a bridge.
        off = build.touch(float(self.long - 6), float(cy - 2), float(a), float(self.long - 4), float(cy + 2), float(a + 6));
        gallery_guard = build.waiting();
        off +>:Fires:+> gallery_guard;
        build.foe(float(self.long) - 2.5, 4.5, a, E3M4_FOES.pick(dice, self.danger), 90.0, waits=gallery_guard);
        build.foe(2.5, float(self.wide) - 6.5, a, E3M4_FOES.pick(dice, self.danger), 270.0, patrol=[[2.5, float(self.wide) - 6.5], [2.5, 6.5]]);
        build.supply(2.5, float(cy) + 0.5, 0, "item_shells");
    }
}

"""A hall of black water, a platform at the near dock set riding over it,
a walkway back high along the wall."""
node BlackCrossing(Prefab) {
    has deep: int = 7,
        tall: int = 19;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Black crossing";
        self.source = E3M4;
        self.district = level_district(E3M4);
        self.long = dice.between(30, 34);
        self.wide = dice.between(17, 20);
        self.deep = min(dice.between(5, 6), self.wide - 9);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle - 1.0, floor=0), Port(face=3, along=float(self.long - 4), floor=0), Port(face=1, along=float(self.long - 4), floor=9)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        fx = self.long - 7;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, 9);
        e2m4_moat(build, 6, fx, 1, self.wide - 1, self.deep);
        # The platform waiting at the near dock, set riding over the water
        # as the player steps to its edge.
        lane = self.wide - 6;
        dock = build.touch(3.0, float(lane), 0.0, 6.0, float(lane + 4), 6.0);
        dock +>:Fires:+> build.train([4.0, 4.0, 1.0], [[6.0, float(lane), -1.0], [float(fx - 4), float(lane), -1.0]], 90.0, 2.0, True);
        for y in range(lane, lane + 4) {
            build.keep(hall, 5, y, 0);
            build.keep(hall, fx, y, 0);
        }
        # The walkway high along the north wall from the far landing back
        # over the water, a stair up to it, its near end open to drop from.
        build.solid(4, self.wide - 6, 8, self.long - 1, self.wide - 1, 9);
        lift(build, self.long - 4, self.wide - 9, self.long - 1, self.wide - 6, 0, 9);
        for x in range(self.long - 4, self.long - 1) {
            build.keep(hall, x, self.wide - 6, 9);
            build.keep(hall, x, self.wide - 10, 0);
        }
        for x in range(4, 7) {
            build.keep(hall, x, self.wide - 7, 9);
        }
        far_touch = build.touch(float(fx), 1.0, 0.0, float(fx + 2), float(self.wide - 1), 6.0);
        far_wake = build.waiting();
        far_touch +>:Fires:+> far_wake;
        build.foe(float(self.long) - 3.5, float(self.wide) - 3.5, 9, E3M4_FOES.pick(dice, self.danger, True), 180.0, waits=far_wake);
        # The far landing's way on opened by a button on its south wall.
        press = build.push(float(fx) + 0.6, 1.0, 1.2, 1);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.face == 0 {
                press +>:Fires:+> e2m4_bars(build, float(self.long - 2), port.along - 2.0, float(self.long - 1), port.along + 2.0, 0, 8, "This door is opened elsewhere.");
            } elif port.face == 3 {
                press +>:Fires:+> e2m4_bars(build, port.along - 2.0, 1.0, port.along + 2.0, 2.0, 0, 8, "This door is opened elsewhere.");
            }
        }
        late = build.delay(2.0);
        dock +>:Fires:+> late;
        late +>:Fires:+> build.summon(1, 2, -8, E3M4_FOES.pick(dice, self.danger, True), float(fx) + 3.5, float(middle) + 0.5, 0, 180.0);
        build.solid(1, 1, 0, 6, 5, 8);
        e2m4_stash(build, 2, 1, 4, 3, 0, 1, "item_artifact_envirosuit");
        # The far landing's keepers wake as the platform sets out.
        guard = build.waiting();
        dock +>:Fires:+> guard;
        for index in range(dice.between(2, 3)) {
            build.foe(float(fx) + 2.5, 3.5 + float(index) * 3.0, 0, E3M4_FOES.pick(dice, self.danger, index == 0), 180.0, waits=guard);
        }
        build.foe(10.5, float(self.wide) - 2.5, 9, "monster_ogre", 0.0, patrol=[[10.5, float(self.wide) - 2.5], [float(self.long) - 6.5, float(self.wide) - 2.5]]);
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 5, "monster_wizard", 180.0);
        build.foe(10.5, 3.5, -self.deep + 1, "monster_fish", 0.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(self.long) - 2.5, 2.5, 0, "item_health");
    }
}

"""The key room: a pool across a vault, a wall down into it to dive under,
the key beyond on a dais; taking it opens the closets."""
node DivedVault(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 14,
        deep: int = 6,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dived vault (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E3M4;
        self.district = level_district(E3M4);
        self.long = dice.between(24, 26);
        self.hall_wide = dice.between(15, 17);
        self.wide = self.hall_wide + 4;
        self.deep = dice.between(5, 6);
        self.tall = dice.between(13, 15);
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
        d = self.deep;
        vault = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(vault, 7);
        build.doorway(vault, self.enter);
        x0 = 7;
        x1 = self.long - 6;
        e2m4_moat(build, x0, x1, 1, side, d, 0, True);
        wall = (x0 + x1) // 2;
        build.solid(wall, 1, -1, wall + 1, side, self.tall);
        # The key's dais beyond the wall.
        build.solid(self.long - 4, cy - 2, 0, self.long - 1, cy + 2, 1);
        # A gallery over the near half of the pool, a lift up to it.
        build.solid(x0, side - 4, 6, wall, side, 7);
        lift(build, 2, side - 4, 5, side - 1, 0, 7);
        for y in range(side - 4, side - 1) {
            build.keep(vault, 5, y, 7);
        }
        lift_gap = [5, x0];
        build.solid(lift_gap[0], side - 4, 6, lift_gap[1], side, 7);
        build.foe(float(wall) - 2.5, float(side) - 2.0, 7, E3M4_FOES.pick(dice, self.danger), 180.0);
        build.supply(float(x0) + 1.5, float(side) - 2.0, 7, "item_artifact_super_damage");
        # The key; taking it opens the closets on the near side and brings a
        # fiend in.
        taken = e2m4_key(build, self.key, float(self.long) - 2.5, float(cy) + 0.5, 1);
        out = build.waiting();
        taken +>:Fires:+> out;
        e2m4_closets(build, [2, x1 + 1], side, 0, taken, out, [E3M4_FOES.pick(dice, self.danger, True), "monster_ogre"]);
        late = build.delay(1.0);
        taken +>:Fires:+> late;
        late +>:Fires:+> build.summon(1, 2, -8, E3M4_FOES.pick(dice, self.danger, True), float(x1) + 1.5, 2.5, 0, 180.0);
        late +>:Fires:+> build.summon(1, 6, -8, "monster_wizard", float(wall) + 2.5, float(cy) + 0.5, 3, 180.0);
        build.foe(float(wall) + 2.5, float(cy) + 0.5, -d + 1, "monster_fish", 0.0);
        build.foe(float(self.long) - 2.5, 2.5, 0, E3M4_FOES.pick(dice, self.danger), 180.0, patrol=[[float(self.long) - 2.5, 2.5], [float(self.long) - 2.5, float(side) - 2.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""The end: a door, a hall of pillars standing in water, a causeway to the
dais of the slipgate, steps rising to it when a button is shot."""
node DelightExit(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Delight exit" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E3M4;
        self.district = level_district(E3M4);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(15, 17);
        self.low = -9;
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
        water = build.room(wall + 1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(water, 8);
        build.doorway(hall, self.enter);
        build.widen(water, wall, middle - 2, 0, wall + 1, middle + 2, 8);
        if self.key {
            e2m4_bars(build, float(wall), float(middle - 2), float(wall + 1), float(middle + 2), 0, 8, "", self.key);
        }
        # The water with pillars standing in it, the causeway across.
        dx = self.long - 7;
        e2m4_moat(build, wall + 4, dx - 4, 1, self.wide - 1, 5, 0, True);
        build.solid(wall + 4, middle - 1, -1, dx - 4, middle + 2, 0);
        pillars(build, wall + 7, 4, dx - 6, self.wide - 4, -5, self.tall, 4, [[wall + 4, middle - 2, dx, middle + 3]]);
        # The dais, climbed only by steps rising out of the floor when the
        # button over it is shot.
        build.solid(dx, 1, 0, self.long - 1, self.wide - 1, 4);
        steps = build.rising_steps(dx - 4, middle - 1, 0, 0, 4, 3);
        build.push(float(self.long - 1), float(middle) + 3.5, 7.0, 2, True) +>:Fires:+> steps;
        build.way_out(float(self.long) - 3.5, float(middle), 4);
        # The gallery along the north wall over the water, ogres on it that
        # wake as the player starts across; a lift up to it.
        build.solid(wall + 1, self.wide - 4, 7, dx, self.wide - 1, 8);
        lift(build, wall + 1, self.wide - 7, wall + 4, self.wide - 4, 0, 8);
        for x in range(wall + 1, wall + 4) {
            build.keep(water, x, self.wide - 4, 8);
        }
        across = build.touch(float(wall + 4), float(middle - 1), 0.0, float(wall + 6), float(middle + 2), 6.0);
        wake = build.waiting();
        across +>:Fires:+> wake;
        for index in range(dice.between(1, 2)) {
            build.foe(float(wall + 8 + index * 6) + 0.5, float(self.wide) - 2.5, 8, "monster_ogre", 270.0, waits=wake);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, E3M4_FOES.pick(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(self.long) - 3.5, 3.5, 4, E3M4_FOES.pick(dice, self.danger, True), 180.0);
        build.foe(float(wall + 8) + 0.5, 3.5, -4, "monster_fish", 0.0);
        late = build.delay(1.5);
        across +>:Fires:+> late;
        late +>:Fires:+> build.summon(1, 6, -8, E3M4_FOES.pick(dice, self.danger, True), float(dx) - 2.5, float(middle) + 3.5, 0, 180.0);
        build.solid(1, 1, 0, 6, 5, 8);
        e2m4_stash(build, 2, 1, 4, 3, 0, 1, "item_artifact_super_damage");
        build.supply(2.5, 2.5, 0, "item_health");
    }
}

"""e3m4's stretches: [name, role]."""
glob E3M4_STRETCHES: list[list[str]] = [
         ["pier", "start"],
         ["elevators", "flow"],
         ["crossing", "flow"],
         ["altar", "hub"],
         ["altar", "flow"],
         ["vault", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of e3m4's stretches by its name."""
def make_e3m4(name: str, key: str) -> Prefab {
    if name == "pier" {
        return DarkPier();
    }
    if name == "elevators" {
        return ElevatorTower();
    }
    if name == "crossing" {
        return BlackCrossing();
    }
    if name == "altar" {
        return DelightAltar();
    }
    if name == "vault" {
        return DivedVault(key=key if key else "key_silver");
    }
    return DelightExit(key=key);
}
