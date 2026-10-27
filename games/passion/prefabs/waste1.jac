"""Prefabs drawn from Quake II's waste1, the Toxic Waste Dump: a yard of
slime pits before a loading canopy whose roof is a second floor, a canyon
of slime crossed low and high, a gallery where a pipe walk crosses over
the way through, settling tanks under a cross of catwalks, the waste
office, the stair down to the pumping stations. Raised in waste1's own
palette.

- `DumpYard`: the start. A yard under the sky, slime pits in it, a loading
  canopy over the far end whose roof is walked, up a stair or a lift. The
  help computer gives the mission (waste1's pumping stations); guards
  appear on the roof as the player crosses; a soldier walks the yard; a
  stash in a block behind a panel.
- `SlimeCanyon`: a canyon across a river of slime, a low bridge over it
  and a high walk between ledges at both ends, lifts up to them. Crossing
  the low bridge sets off the drums in the river and brings guards onto
  the far ledge.
- `PipeGallery`: a pipe walk high across a gallery over a slime trench,
  the way through passing under it on a low bridge, a stair up beside it,
  sometimes a mezzanine joined to it along the far wall.
- `SettlingTanks`: a hub. Four sunk tanks of slime, walks between them,
  and over the walks a cross of catwalks reaching every wall, up a stair
  and a lift.
- `WasteOffice`: the key room. A hall under an office floor up a stair or
  a lift, the key in the office; taking it opens the closets below.
- `PumpAccess`: the end. A door (a key's, as a gate), then a stair down
  the walls of a deep pit to the way on to the pumping stations, slime
  along its foot."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, key_ambush }
import from .plant_parts { key_doors, open_ways, charges, sparking, stash, crate_pile, squad, keep_box, plat }

glob WASTE1: str = "q2:waste1";

"""waste1's foes: gunners and soldiers, iron maidens and berserkers, hovers,
a tank deeper in."""
def waste1_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_hover";
    }
    return q1_foe(dice, q1_palette(["monster_gunner", "monster_berserk"] if heavy else ["monster_soldier", "monster_gunner", "monster_chick"], ["monster_tank"] if heavy else ["monster_berserk"], danger * 0.3 if heavy else danger * 0.6));
}

"""The start: a yard of slime pits, a loading canopy over its far end."""
node DumpYard(Prefab) {
    has roof: int = 9,
        tall: int = 20,
        climb_lift: bool = False,
        second: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Dump yard";
        self.source = WASTE1;
        self.district = level_district(WASTE1);
        self.long = dice.between(30, 34);
        self.wide = dice.between(24, 28);
        self.roof = dice.between(9, 10);
        self.tall = self.roof + dice.between(10, 12);
        self.climb_lift = dice.chance(0.4);
        self.second = dice.chance(0.6);
        self.low = -4;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=cy, floor=self.roof), Port(face=3, along=float(self.long // 2 + 2), floor=0), Port(face=3, along=float(self.long - 6), floor=self.roof)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        r = self.roof;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, r);
        # The canopy over the far end, its roof walked, on pillars.
        cx0 = self.long - 12;
        build.solid(cx0, 1, r - 1, self.long - 1, self.wide - 1, r);
        for y in [5, self.wide - 6] {
            build.solid(cx0, y, 0, cx0 + 1, y + 1, r - 1);
        }
        if self.climb_lift {
            plat(build, yard, cx0 - 3, self.wide - 5, cx0, self.wide - 2, 0, r);
        } else {
            stair(build, cx0 - r, self.wide - 4, 0, 0, r, 3);
        }
        # The slime pits.
        build.pool(6, 2, -3, 12, 8, 0, 3);
        if self.second {
            build.pool(14, self.wide - 10, -3, 20, self.wide - 5, 0, 3);
        }
        # A block in the near corner, a stash behind a panel in it.
        build.solid(1, self.wide - 6, 0, 5, self.wide - 1, 6);
        stash(build, self.wide - 6, 2, 0, False, -1, "item_adrenaline");
        crate_pile(build, self.long - 10, 1, 0, 0, 2);
        # A store under the canopy, its shutter raised by the switch beside
        # it on what waits inside.
        build.solid(self.long - 6, self.wide - 7, 0, self.long - 1, self.wide - 1, r - 1);
        build.room(self.long - 6, self.wide - 6, 0, self.long - 2, self.wide - 2, 5);
        shutter = build.opened(float(self.long - 6), float(self.wide - 6), 0.0, float(self.long - 5), float(self.wide - 2), 5.0);
        lever = build.push(float(self.long) - 4.5, float(self.wide - 7), 1.5, 3);
        lever +>:Fires:+> shutter;
        squad(build, lever, [[float(self.long) - 3.5, float(self.wide) - 4.0, 0.0]], [waste1_foe(dice, self.danger, True)], 180.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, 0, "ammo_rockets", "q2");
        open_ways(build, yard, self);
        build.start(2.5, float(cy) + 0.5, 0, 0.0);
        build.supply(2.5, float(cy) - 1.5, 0, "ammo_shells", "q2");
        build.touch(1.0, float(cy - 3), 0.0, 5.0, float(cy + 3), 8.0) +>:Fires:+> build.objective("Proceed to Pumping Stations.\nActivate stations one\nand two.");
        # Guards appear on the canopy's roof as the player crosses.
        crossing = build.touch(float(self.long // 2 - 1), 1.0, 0.0, float(self.long // 2 + 1), float(self.wide - 1), 6.0);
        squad(build, crossing, [[float(self.long) - 4.5, float(cy) - 4.5, float(r)], [float(self.long) - 4.5, float(cy) + 4.5, float(r)]], ["monster_gunner", waste1_foe(dice, self.danger)], 180.0);
        build.foe(4.5, float(cy) + 0.5, 0, "monster_soldier", 0.0, patrol=[[4.5, float(cy) + 0.5], [float(cx0) - 2.5, float(cy) + 0.5], [float(cx0) - 2.5, 10.5]]);
        build.foe(float(cx0) + 4.5, float(cy) + 0.5, 0, waste1_foe(dice, self.danger, True), 180.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long // 2 + 3) + 0.5, 4.5 + float(index) * 8.0, 0, waste1_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(cy) + 0.5, r + 4, "monster_hover", 180.0);
        sparking(build, dice.uniform(4.0, 6.0), float(cx0) + 0.5, 5.2, float(r) - 3.0, 1);
        build.supply(float(self.long) - 3.0, float(self.wide) - 3.0, r, Q2_HEALTH, "q2");
    }
}

"""A canyon across a river of slime, a low bridge and a high walk between
ledges at both ends."""
node SlimeCanyon(Prefab) {
    has high_walk: int = 9,
        tall: int = 20,
        river: int = 6,
        low_y: int = 8,
        high_y: int = 8;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Slime canyon";
        self.source = WASTE1;
        self.district = level_district(WASTE1);
        self.long = dice.between(30, 34);
        self.wide = dice.between(18, 22);
        self.high_walk = dice.between(11, 14);
        self.tall = self.high_walk + dice.between(8, 10);
        self.river = dice.between(5, 7);
        cy = self.wide // 2;
        self.low_y = dice.between(4, self.wide - 7);
        self.low_y = min(self.low_y, self.wide - 9) if dice.chance(0.5) else self.low_y;
        self.high_y = self.low_y if dice.chance(0.5) and self.low_y <= self.wide - 9 else dice.between(4, self.wide - 9);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(cy), floor=0);
        self.leaves = [Port(face=0, along=float(cy), floor=0), Port(face=0, along=float(cy), floor=self.high_walk), Port(face=3, along=4.0, floor=self.high_walk), Port(face=1, along=float(self.long - 4), floor=self.high_walk)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        h = self.high_walk;
        canyon = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(canyon, h);
        build.level(canyon, -8);
        # The river of slime across the canyon, the low bridge over it.
        r0 = self.long // 2 - self.river // 2;
        r1 = r0 + self.river;
        build.pool(r0, 1, -8, r1, self.wide - 1, 0, 3);
        build.solid(r0, self.low_y, -1, r1, self.low_y + 3, 0);
        keep_box(build, canyon, r0 - 1, self.low_y, r1 + 1, self.low_y + 3, 0);
        # The ledges at both ends and the high walk between them.
        build.solid(1, 1, h - 1, 7, self.wide - 1, h);
        build.solid(self.long - 7, 1, h - 1, self.long - 1, self.wide - 1, h);
        build.solid(7, self.high_y, h - 1, self.long - 7, self.high_y + 3, h);
        plat(build, canyon, 7, self.wide - 5, 10, self.wide - 2, 0, h);
        plat(build, canyon, self.long - 10, self.wide - 5, self.long - 7, self.wide - 2, 0, h);
        open_ways(build, canyon, self);
        high = build.touch(7.0, float(self.high_y), float(h), 9.0, float(self.high_y + 3), float(h + 6));
        squad(build, high, [[float(self.long // 2), float(self.high_y) + 1.5, float(h)]], ["monster_gunner"], 180.0);
        # Crossing the low bridge sets off the drums in the river and
        # brings guards onto the far ledge.
        over = build.touch(float(r0), float(self.low_y), 0.0, float(r0 + 2), float(self.low_y + 3), 6.0);
        charges(build, over, [[float(r0) + 1.0, 2.5, -2.0], [float(r1) - 1.0, float(self.wide) - 2.5, -2.0]], 0.4);
        squad(build, over, [[float(self.long) - 3.5, 3.5, float(h)], [float(self.long) - 3.5, float(self.wide) - 3.5, float(h)]], [waste1_foe(dice, self.danger), "monster_gunner"], 180.0);
        build.foe(8.5, float(self.high_y) + 1.5, h, "monster_soldier", 0.0, patrol=[[8.5, float(self.high_y) + 1.5], [float(self.long) - 8.5, float(self.high_y) + 1.5]]);
        build.foe(float(r0) + 2.5, float(cy) + 0.5, 4, "monster_hover", 90.0, patrol=[[float(r0) + 2.5, 3.5], [float(r0) + 2.5, float(self.wide) - 3.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(r1) + 3.5 + float(index % 2) * 3.0, 3.5 + float(index) * 4.0, 0, waste1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(3.5, float(cy) + 0.5, h, waste1_foe(dice, self.danger), 0.0);
        build.supply(3.0, 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(self.long) - 3.0, float(cy) + 0.5, h, "ammo_bullets", "q2");
    }
}

"""A pipe walk high across a gallery over a slime trench, the way through
passing under it."""
node PipeGallery(Prefab) {
    has walk: int = 9,
        tall: int = 18,
        pipe_x: int = 12,
        trench: bool = True,
        mezzanine: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pipe gallery";
        self.source = WASTE1;
        self.district = level_district(WASTE1);
        self.long = dice.between(26, 30);
        self.wide = dice.between(24, 28);
        self.walk = dice.between(9, 13);
        self.tall = self.walk + dice.between(8, 10);
        self.pipe_x = dice.between(9, self.long - 15);
        self.trench = dice.chance(0.65);
        self.mezzanine = dice.chance(0.6);
        self.low = -5;
        self.high = self.tall + 1;
        cy = float(self.wide // 2);
        px = float(self.pipe_x) + 2.0;
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=1, along=px, floor=self.walk), Port(face=3, along=px, floor=self.walk)];
        if self.mezzanine {
            self.leaves.append(Port(face=0, along=cy, floor=self.walk));
        } else {
            self.leaves.append(Port(face=1, along=float(self.long - 5), floor=0));
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cy = self.wide // 2;
        px = self.pipe_x;
        h = self.walk;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, h);
        # The pipe walk across the gallery, a stair up beside it.
        build.solid(px, 1, h - 1, px + 4, self.wide - 1, h);
        stair(build, px + 4, 1, 0, 1, h, 3);
        if self.trench {
            # The slime trench under the walk, the way through bridging it.
            build.pool(px, 5, -4, px + 4, self.wide - 5, 0, 3);
            build.solid(px, cy - 2, -1, px + 4, cy + 2, 0);
            keep_box(build, hall, px - 1, cy - 2, px + 5, cy + 2, 0);
        }
        if self.mezzanine {
            # A mezzanine along the far wall, joined to the walk along the
            # high wall.
            build.solid(self.long - 6, 1, h - 1, self.long - 1, self.wide - 1, h);
            build.solid(px + 4, self.wide - 4, h - 1, self.long - 6, self.wide - 1, h);
        }
        # Pipes along the low wall.
        for x in range(2, px - 2, 6) {
            build.solid(x, 1, 0, x + 4, 3, 2);
        }
        open_ways(build, hall, self);
        up = build.touch(float(px + 4), float(h - 2), float(h - 1), float(px + 7), float(h + 1), float(h + 6));
        squad(build, up, [[float(px) + 2.0, float(self.wide) - 3.0, float(h)], [float(px) + 2.0, float(cy) + 4.0, float(h)]], ["monster_gunner", waste1_foe(dice, self.danger)], 270.0);
        under = build.touch(float(px - 2), float(cy - 2), 0.0, float(px), float(cy + 2), 6.0);
        squad(build, under, [[float(self.long) - 4.5, float(cy) + 4.5, 0.0]], [waste1_foe(dice, self.danger, True)], 180.0);
        build.foe(float(px) + 2.0, 3.5, h, "monster_soldier", 90.0, patrol=[[float(px) + 2.0, 3.5], [float(px) + 2.0, float(self.wide) - 3.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(px + 8 + index * 3) + 0.5, float(cy) + (4.5 if index % 2 == 0 else -4.5), 0, waste1_foe(dice, self.danger), 180.0);
        }
        build.foe(4.5, float(cy) + 4.5, 0, waste1_foe(dice, self.danger), 0.0);
        sparking(build, dice.uniform(3.0, 5.0), float(px) - 0.2, float(self.wide) - 3.0, float(h) - 2.0, 2);
        crate_pile(build, self.long - 5, 1, 0, 2, 1);
        build.supply(float(self.long) - 3.0, 3.0, 0, Q2_HEALTH, "q2");
        build.supply(float(px) + 2.0, float(self.wide) - 3.0, h, "ammo_grenades", "q2");
    }
}

"""Four sunk tanks of slime, walks between them, a cross of catwalks over
the walks."""
node SettlingTanks(Prefab) {
    has walk: int = 9,
        tall: int = 19,
        tanks: list[bool] = [],
        booth: int = 0,
        climb: int = 1;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Settling tanks";
        self.source = WASTE1;
        self.district = level_district(WASTE1);
        self.long = dice.between(32, 36);
        self.wide = dice.between(30, 34);
        self.walk = dice.between(9, 10);
        self.tall = self.walk + dice.between(9, 11);
        self.tanks = [True, True, True, True];
        self.booth = dice.below(4);
        self.tanks[self.booth] = False;
        self.tanks[(self.booth + 1 + dice.below(3)) % 4] = dice.chance(0.6);
        self.climb = dice.below(3);
        self.low = -5;
        self.high = self.tall + 1;
        cx = float(self.long // 2);
        cy = float(self.wide // 2);
        self.enter = Port(face=2, along=cy, floor=0);
        self.leaves = [Port(face=0, along=cy, floor=0), Port(face=0, along=cy, floor=self.walk), Port(face=1, along=cx, floor=self.walk), Port(face=3, along=cx, floor=self.walk), Port(face=1, along=float(self.long - 6), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        h = self.walk;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(yard, h);
        # The tanks: four pools of slime in a square round the walks.
        tw = cx - 8;
        th = cy - 8;
        corners = [[5, 5], [cx + 3, 5], [5, cy + 3], [cx + 3, cy + 3]];
        for (index, corner) in enumerate(corners) {
            if index == self.booth {
                # The control booth: a block seven lifts up, a stair cut
                # into its side up to its roof; a closet in it from which
                # guards teleport out, and a stash behind a panel.
                c0 = corner[0];
                c1 = corner[1];
                west = c0 < cx;
                build.solid(c0, c1, 0, c0 + tw, c1 + th, 7);
                # The stair climbs into the block from the walk beside it.
                if west {
                    build.widen(yard, c0 + tw - 7, c1, 0, c0 + tw, c1 + 3, 7);
                    stair(build, c0 + tw - 1, c1, 0, 2, 7, 3);
                } else {
                    build.widen(yard, c0, c1, 0, c0 + 7, c1 + 3, 7);
                    stair(build, c0, c1, 0, 0, 7, 3);
                }
                build.level(yard, 7);
                booth_cue = build.touch(float(c0), float(c1 + 3), 7.0, float(c0 + tw), float(c1 + th), 13.0);
                booth_cue +>:Fires:+> build.summon(c0 + tw - 4 if west else c0 + 1, c1 + th - 4, 0, waste1_foe(dice, self.danger, True), float(cx) + 0.5, float(cy) + 0.5, 0, 0.0);
                if west {
                    stash(build, c0, c1 + th - 3, 0, True, -1, Q2_ARMOR);
                } else {
                    stash(build, c0 + tw, c1 + th - 3, 0, True, 1, Q2_ARMOR);
                }
            } elif self.tanks[index] {
                build.pool(corner[0], corner[1], -4, corner[0] + tw, corner[1] + th, 0, 3);
            } else {
                # A tank drained: a dry pit with steps down, crates in it.
                build.room(corner[0], corner[1], -3, corner[0] + tw, corner[1] + th, 0);
                build.level(yard, -3);
                stair(build, corner[0] + 2, corner[1], -3, 2, 3, th);
                build.solid(corner[0] + tw - 3, corner[1] + 1, -3, corner[0] + tw - 1, corner[1] + 3, -1);
            }
        }
        # The cross of catwalks over the walks, reaching every wall.
        build.solid(1, cy - 2, h - 1, self.long - 1, cy + 2, h);
        build.solid(cx - 2, 1, h - 1, cx + 2, self.wide - 1, h);
        stair(build, cx - 2 - h, 1, 0, 0, h, 3);
        if self.climb == 1 {
            plat(build, yard, cx + 2, self.wide - 5, cx + 5, self.wide - 2, 0, h);
        } elif self.climb == 2 {
            build.train([3.0, 3.0, 1.0], [[float(cx + 2), float(self.wide - 5), 0.0], [float(cx + 2), float(self.wide - 5), float(h - 1)]], 60.0, 3.0);
            keep_box(build, yard, cx + 1, self.wide - 5, cx + 2, self.wide - 2, h);
        }
        open_ways(build, yard, self);
        # Up on the catwalks, guards appear at the ends of the cross.
        up = build.touch(float(cx - 2), 1.0, float(h), float(cx + 2), 5.0, float(h + 6));
        squad(build, up, [[3.5, float(cy) + 0.5, float(h)], [float(cx) + 0.5, float(self.wide) - 3.5, float(h)]], ["monster_gunner", waste1_foe(dice, self.danger)], 0.0);
        middle = build.touch(float(cx - 3), float(cy - 3), 0.0, float(cx + 3), float(cy + 3), 6.0);
        squad(build, middle, [[float(self.long) - 3.5, 3.5, 0.0], [float(self.long) - 3.5, float(self.wide) - 3.5, 0.0]], [waste1_foe(dice, self.danger, True), waste1_foe(dice, self.danger)], 180.0);
        build.foe(3.0, 6.0, 0, "monster_soldier", 0.0, patrol=[[3.0, 6.0], [3.0, float(self.wide) - 3.0]]);
        build.foe(float(self.long) - 4.5, float(cy) + 0.5, h, "monster_gunner", 180.0, patrol=[[float(self.long) - 4.5, float(cy) + 0.5], [4.5, float(cy) + 0.5]]);
        build.foe(float(cx) + 0.5, float(cy) + 6.5, 4, "monster_hover", 270.0);
        for index in range(dice.between(1, 2)) {
            build.foe(float(cx) + 0.5, float(cy) - 6.5 + float(index) * 13.0, 0, waste1_foe(dice, self.danger), 180.0);
        }
        sparking(build, dice.uniform(4.0, 6.0), float(cx) + 2.2, float(cy) + 2.2, float(h) - 2.0, 0);
        crate_pile(build, self.long - 4, 6, 0, 1, 2);
        build.supply(float(cx) + 0.5, float(cy) + 0.5, 0, Q2_HEALTH, "q2");
        build.supply(3.0, float(cy) + 0.5, h, "ammo_rockets", "q2");
    }
}

"""The key room: a hall under an office floor, the key in the office."""
node WasteOffice(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 18,
        office: int = 7,
        climb_lift: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Waste office (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = WASTE1;
        self.district = level_district(WASTE1);
        self.long = dice.between(23, 26);
        self.hall_wide = dice.between(18, 20);
        self.wide = self.hall_wide + 4;
        self.office = dice.between(5, 6);
        self.climb_lift = dice.chance(0.4);
        self.low = -1;
        self.high = self.office + 9;
        self.enter = Port(face=2, along=float(self.hall_wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hall_wide - 1;
        cy = side // 2;
        m = self.office;
        hall = build.room(1, 1, 0, self.long - 1, side, m + 8, variant=dice.below(3));
        build.level(hall, m);
        build.doorway(hall, self.enter);
        ox = self.long - 10;
        build.solid(ox, 1, m - 1, self.long - 1, side, m);
        # The office's partition, a doorway through it.
        build.solid(ox + 3, 1, m, ox + 4, side, m + 5);
        build.widen(hall, ox + 3, cy - 1, m, ox + 4, cy + 2, m + 5);
        office_door = build.opened(float(ox + 3), float(cy - 1), float(m), float(ox + 4), float(cy + 2), float(m + 5));
        build.push(float(ox + 3), float(cy) + 3.5, float(m) + 1.2, 2) +>:Fires:+> office_door;
        # A block in the near corner of the floor, a stash in it.
        build.solid(2, 1, 0, 6, 5, 5);
        stash(build, 5, 3, 0, False, 1, "item_adrenaline");
        if self.climb_lift {
            plat(build, hall, ox - 3, 2, ox, 5, 0, m);
        } else {
            stair(build, ox - m, 1, 0, 0, m, 3);
        }
        key_ambush(build, self.key, float(self.long) - 3.5, float(cy) + 0.5, m, side, 0, [3, 9], [waste1_foe(dice, self.danger, True), waste1_foe(dice, self.danger)]);
        landing = build.touch(float(ox), 1.0, float(m), float(ox + 2), float(side), float(m + 5));
        squad(build, landing, [[float(self.long) - 3.5, float(side) - 3.5, float(m)]], [waste1_foe(dice, self.danger)], 180.0);
        inside = build.touch(float(ox + 4), 1.0, float(m), float(ox + 6), float(side), float(m + 5));
        squad(build, inside, [[float(ox) - 3.5, float(side) - 3.5, 0.0], [4.5, float(cy) + 0.5, 0.0]], [waste1_foe(dice, self.danger), "monster_gunner"], 0.0);
        inside +>:Fires:+> build.explosion(float(ox) - 2.0, float(cy), 3.0);
        build.foe(float(self.long) - 3.5, 3.5, m, waste1_foe(dice, self.danger, True), 180.0);
        build.foe(7.5, 6.5, 0, "monster_soldier", 0.0, patrol=[[7.5, 6.5], [float(self.long) - 4.5, 6.5]]);
        sparking(build, dice.uniform(4.0, 6.0), float(ox) + 0.5, 1.2, float(m) - 2.5, 1);
        build.supply(2.5, float(side) - 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a stair down the walls of a deep pit to the way on."""
node PumpAccess(Prefab) {
    has key: str = "",
        deep: int = 12,
        tall: int = 10,
        bottom_steps: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Pump access" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = WASTE1;
        self.district = level_district(WASTE1);
        self.deep = dice.between(10, 14);
        self.long = self.deep + dice.between(20, 23);
        self.wide = dice.between(18, 21);
        self.tall = dice.between(10, 12);
        self.bottom_steps = dice.chance(0.5);
        self.low = -self.deep - 4;
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
        d = self.deep;
        hall = build.room(1, 1, 0, wall, self.wide - 1, 10, variant=dice.below(3));
        build.doorway(hall, self.enter);
        pit = build.room(wall + 1, 1, -d, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(pit, 0);
        build.widen(pit, wall, cy - 2, 0, wall + 1, cy + 2, 8);
        if self.key {
            key_doors(build, float(wall), float(cy - 2), float(cy + 2), self.key);
        }
        # The landing inside the door, the stair down the low wall.
        build.solid(wall + 1, 1, -d, wall + 5, self.wide - 1, 0);
        stair(build, wall + 4 + d, 1, -d, 2, d, 3);
        # Slime along the pit's high wall.
        build.pool(wall + 8, self.wide - 5, -d - 3, self.long - 1, self.wide - 1, -d, 3, False, False);
        if not self.bottom_steps {
            # A freight platform beside the landing, down to the pit's floor.
            build.train([3.0, 3.0, 1.0], [[float(wall + 5), float(self.wide - 9), float(-d)], [float(wall + 5), float(self.wide - 9), -1.0]], 60.0, 3.0);
            keep_box(build, pit, wall + 4, self.wide - 9, wall + 5, self.wide - 6, 0);
        }
        build.way_out(float(self.long) - 4.0, float(cy) - 1.0, -d);
        down = build.touch(float(wall + 5 + d), 1.0, float(-d), float(wall + 7 + d), float(self.wide - 5), float(-d + 6));
        squad(build, down, [[float(self.long) - 4.5, 3.5, float(-d)], [float(self.long) - 6.5, float(cy) + 1.5, float(-d)]], [waste1_foe(dice, self.danger, True), waste1_foe(dice, self.danger)], 180.0);
        charges(build, down, [[float(self.long) - 3.0, float(self.wide) - 3.0, float(-d + 2)]], 0.5);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, waste1_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(wall + d + 8) + 0.5, float(cy) + 0.5, -d + 5, "monster_hover", 180.0, patrol=[[float(wall + d + 8) + 0.5, float(cy) + 0.5], [float(self.long) - 4.5, float(cy) + 0.5]]);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""waste1's stretches: [name, role]."""
glob WASTE1_STRETCHES: list[list[str]] = [
         ["yard", "start"],
         ["canyon", "flow"],
         ["pipes", "flow"],
         ["tanks", "hub"],
         ["pipes", "hub"],
         ["office", "keyroom"],
         ["access", "end"],
         ["access", "gate"]
     ];

"""One of waste1's stretches by its name."""
def make_waste1(name: str, key: str) -> Prefab {
    if name == "yard" {
        return DumpYard();
    }
    if name == "canyon" {
        return SlimeCanyon();
    }
    if name == "pipes" {
        return PipeGallery();
    }
    if name == "tanks" {
        return SettlingTanks();
    }
    if name == "office" {
        return WasteOffice(key=key if key else "key_silver");
    }
    return PumpAccess(key=key);
}
