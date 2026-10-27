"""Prefabs drawn from e1m6, the Door to Chthon: halls over lava, stone
causeways across it, doors opened from elsewhere, a shaft whose stair
rises out of its floor, a gallery whose closets open one after another, a
key on an island the lava keeps until a bridge rises, and the great door
down to the way out. Raised in e1m6's own palette; dense with doors,
buttons and triggers as e1m6 is. Each stretch takes its shape from its
dice as well as its sizes.

- `LavaOverlook`: the start. A balcony high over a lava hall (a stash in
  its rock, a teleporter in it to the far landing), a lift down, or a
  stair that rises out of the floor as the player steps to the edge; the
  button at the foot opens the ways on (e1m6's first button and its door);
  a causeway winding across the lava, an ogre sent in behind halfway; the
  far landing's closets open and its ogres wake as the player arrives.
- `DoorMaze`: a corridor of doors, rooms behind them, a cross passage whose
  arms go down a stair, or up one, or stay level, to its ways out; the
  ways on are shut, each opened by a button in one of the rooms ("This
  door is opened elsewhere"); rooms that open as the corridor's middle is
  reached, a vault behind a key's door, and a secret room behind a door
  that opens when shot (a hub, and a stretch passed through).
- `LavaCauseway`: a long hall floored with lava, a causeway down it,
  ledges high on both sides (a lift up to one, sometimes a bridge across
  to the other); the button on the ledge opens the way on below; spikes
  fly across the causeway; halfway, closets on the ledge open and a fiend
  is sent in behind; a stash in the wall at the ledge's height.
- `SinkingStair`: a deep shaft, rims round it over its floor; touching
  the rim raises a stair out of the shaft's floor a moment later (e1m6's
  stair of doors), spikes flying across it; a hoist riding back up (and
  sometimes a lift); a stash at the foot with a teleporter back to the
  rim; a foe sent in as the bottom is reached.
- `ZombieGallery`: a hall with a high gallery round three sides (a lift
  up); the button (on a plinth, or on the gallery) starts a sequence:
  closets in the gallery's wall open one after another, an ogre is sent
  in and the closets below open, and at the last the way on opens (e1m6's
  chain of delayed triggers).
- `LavaKeyShrine`: the key on an island in lava; a bridge drawn up by a
  button on the shore or shot on the far wall; stepping onto the island
  wakes its keeper and brings a scrag in; taking the key opens the
  closets, sends one in behind and opens the key's own vault on the
  shore; teleporters to a ledge over the lava and back.
- `ChthonDoor`: the end: a pillared hall, the great door (a key's, as a
  gate, or one that rises after the plate before it is stepped on), a
  landing beyond with galleries over a stair down to a lava moat, crossed
  by a stone way or (a gap in it) a riding platform, the way out beyond;
  the far guards' deaths count to a cache."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires }
import from ..kits { level_district, kit_of }
import from ..space { Space }
import from .roster { q1_foe, q1_palette }
import from .common { stair, pillars, apart, lift }
import from .e1m2_parts { slab, keep_box, arcade, stash, closets, spike_wall, key_cue }
import from .e1m2 { port_gate }

glob E1M6: str = "q1:e1m6";

"""e1m6's foes: ogres above all, zombies and scrags, a fiend deeper in."""
def e1m6_foe(dice: Stream, danger: float, heavy: bool = False) -> str {
    return q1_foe(dice, q1_palette(["monster_ogre", "monster_ogre", "monster_knight"] if heavy else ["monster_ogre", "monster_zombie", "monster_knight"], ["monster_demon1"] if heavy else ["monster_wizard"], danger));
}

"""A foe standing on a floor whose death is a cue: what it is wired to
fires as it dies (e1m6's ogres counted as they fall)."""
def foe_cue(build: Raising, x: float, y: float, z: int, kind: str, angle: float) -> Cue {
    fields = {"classname": kind, "angle": str(build.heading(angle)), "asset_game": "q1"};
    build.put_at(fields, x, y, z);
    build.casting.monsters += 1;
    return build.cue([fields], "death");
}

"""The start: a balcony over a lava hall, a way down, the button that opens
the ways on, a causeway winding across."""
node LavaOverlook(Prefab) {
    has top: int = 11,
        hall: int = 8,
        span: int = 15,
        far_side: int = 6,
        tall: int = 21,
        lifted: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava overlook";
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.top = dice.between(15, 17);
        self.hall = dice.between(8, 9);
        self.span = dice.between(14, 17);
        self.far_side = dice.between(6, 7);
        self.wide = dice.between(16, 18) + 5;
        self.lifted = dice.chance(0.5);
        foot = 1 + self.hall + (5 if self.lifted else self.top + 2);
        self.long = foot + self.span + self.far_side + 1;
        self.tall = self.top + dice.between(9, 11);
        self.low = -self.top - 2;
        self.high = self.tall + 1;
        mid = (5 + self.wide - 1) // 2;
        land = foot + self.span;
        self.enter = Port(face=2, along=float(mid), floor=self.top);
        self.leaves = [
            Port(face=0, along=float(mid), floor=0),
            Port(face=1, along=float(land + self.far_side // 2), floor=0),
            Port(face=0, along=float(self.wide - 4), floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        y0 = 5;
        y1 = self.wide - 1;
        mid = (y0 + y1) // 2;
        pit = build.room(1, y0, 0, self.long - 1, y1, self.tall, variant=dice.below(3));
        build.level(pit, self.top);
        # The balcony: rock at its back, an overhang on pillars at its front.
        build.solid(1, y0, 0, 5, y1, self.top);
        slab(build, 5, y0, 1 + self.hall, y1, self.top);
        arcade(build, self.hall, y0 + 3, y1 - 2, 0, self.top - 1, 4, True);
        brink = 1 + self.hall;
        # Down: a lift, or a stair along the side wall.
        if self.lifted {
            lift(build, brink, mid - 1, brink + 3, mid + 2, 0, self.top);
            keep_box(build, pit, brink - 1, mid - 2, brink + 4, mid + 3, self.top);
            keep_box(build, pit, brink, mid - 2, brink + 4, mid + 3, 0);
            foot_x = brink + 3;
        } else {
            # The stair rises out of the floor as the player steps to the
            # balcony's edge.
            risen = build.rising_steps(brink + self.top - 1, y0, 0, 2, self.top, 3);
            keep_box(build, pit, brink - 1, y0, brink + 1, y0 + 3, self.top);
            foot_x = brink + self.top;
        }
        # The button at the foot, on a post; it opens the ways on.
        build.solid(foot_x + 1, mid + 3, 0, foot_x + 2, mid + 4, 3);
        press = build.push(float(foot_x + 1), float(mid) + 3.5, 1.2, 2);
        build.touch(float(foot_x - 2), float(y0), 0.0, float(foot_x + 1), float(y1), 6.0, True, "The way on is opened by the button");
        # The lava, a causeway winding across it.
        lava_x0 = foot_x + 2;
        lava_x1 = lava_x0 + self.span;
        build.pool(lava_x0, y0, -3, lava_x1, y1, 0, 4);
        y = mid - 1;
        x = lava_x0;
        while x < lava_x1 {
            run = min(lava_x1 - x, dice.between(3, 5));
            build.solid(x, y, -3, x + run, y + 3, 0);
            x += run;
            if x < lava_x1 {
                turn = dice.between(-4, 4);
                low = max(y0 + 1, min(y1 - 4, y + turn));
                build.solid(x - 3, min(y, low), -3, x, max(y, low) + 3, 0);
                y = low;
            }
        }
        build.doorway(pit, self.enter);
        for port in self.taken {
            build.doorway(pit, port);
            if port.floor == 0 {
                press +>:Fires:+> port_gate(build, self.long, self.wide, port);
            }
        }
        # Halfway over the lava, an ogre is sent in onto the near floor.
        halfway = build.touch(float(lava_x0 + self.span // 2 - 1), float(y0), 0.0, float(lava_x0 + self.span // 2 + 1), float(y1), 6.0);
        halfway +>:Fires:+> build.summon(2, y1 - 4, -8, e1m6_foe(dice, self.danger, True), float(foot_x), float(mid) - 2.5, 0, 0.0);
        # The secret: a stash in the balcony's rock, a teleporter in it to the
        # far landing.
        stash(build, 5, y0 + 1, 0, 2, "item_armor2");
        build.teleporter(2.0, float(y0) + 2.0, 0, float(lava_x1) + 2.5, float(mid) + 0.5, 0, 0.0);
        build.start(2.5, float(mid) + 0.5, self.top, 0.0);
        build.supply(2.5, float(y1) - 2.5, self.top, "item_shells");
        # Stepping to the balcony's edge wakes the floor's ogres and sends a
        # scrag in over the lava.
        rim = build.touch(float(brink - 2), float(y0), float(self.top), float(brink), float(y1), float(self.top + 6));
        if not self.lifted {
            rim +>:Fires:+> risen;
        }
        floor_foes = build.waiting();
        rim +>:Fires:+> floor_foes;
        rim +>:Fires:+> build.summon(2, y0 + 4, -8, "monster_wizard", float(lava_x0) + 4.5, float(mid) + 0.5, 5, 180.0);
        for index in range(2) {
            build.foe(float(foot_x) - 0.5 - float(index) * 2.0, float(y1) - 2.5, 0, e1m6_foe(dice, self.danger), 180.0, waits=floor_foes);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(lava_x0 + 4 + index * 5) + 0.5, float(mid) + 0.5, 6, "monster_wizard", 180.0);
        }
        # The far landing's closets open and its guards wake as the player
        # arrives.
        landed = build.touch(float(lava_x1), float(y0), 0.0, float(lava_x1 + 2), float(y1), 6.0);
        closets(build, landed, y0, [lava_x1 + 1], 0, 3, [e1m6_foe(dice, self.danger, True)]);
        guards = build.waiting();
        landed +>:Fires:+> guards;
        for index in range(2) {
            build.foe(float(self.long) - 2.5, float(mid) - 2.5 + float(index) * 5.0, 0, e1m6_foe(dice, self.danger, index == 0), 180.0, waits=guards);
        }
        build.foe(float(lava_x1) + 2.5, float(y1) - 2.5, 0, "monster_knight", 270.0, patrol=[[float(lava_x1) + 2.5, float(y1) - 2.5], [float(lava_x1) + 2.5, float(y0) + 5.5]]);
        build.supply(float(self.long) - 2.5, float(y1) - 2.5, 0, "item_health");
    }
}

"""A corridor of doors, rooms behind them, a cross passage whose arms go
down (or up) a stair to its ways out; the ways on shut, each opened by a
button in one of the rooms."""
node DoorMaze(Prefab) {
    has rooms: int = 4,
        tall: int = 11,
        order: list[int] = [],
        drop: int = 0;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Door maze";
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.rooms = dice.between(4, 5);
        self.long = 2 + self.rooms * 7 + 1;
        self.tall = dice.between(11, 12);
        self.order = dice.order(8);
        self.drop = [-10, 0, 10][dice.below(3)];
        steps = abs(self.drop);
        self.wide = 2 * max(steps, 8) + 10;
        self.low = -21;
        self.high = max(self.tall, self.drop + 10) + 1;
        c0 = max(steps, 8) + 3;
        self.enter = Port(face=2, along=float(c0 + 2), floor=0);
        self.leaves = [Port(face=0, along=float(c0 + 2), floor=0), Port(face=1, along=float(self.long // 2), floor=self.drop), Port(face=3, along=float(self.long // 2), floor=self.drop)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        door = kit_of(build.district).door;
        steps = abs(self.drop);
        c0 = max(steps, 8) + 3;
        c1 = c0 + 4;
        hall = build.room(1, c0, 0, self.long - 1, c1, self.tall, variant=dice.below(3));
        mid = self.long // 2;
        # The cross passage's arms, each a straight stair down (or up) to a
        # way out, or level.
        top = max(self.tall, self.drop + 10);
        arms: list[Space] = [];
        for (a0, a1, toward) in [(1, c0, -1), (c1, self.wide - 1, 1)] {
            arms.append(build.room(mid - 2, a0, min(0, self.drop), mid + 2, a1, top));
            if self.drop != 0 {
                for step in range(steps) {
                    y = c0 - 1 - step if toward < 0 else c1 + step;
                    if self.drop < 0 {
                        build.solid(mid - 2, y, self.drop, mid + 2, y + 1, -1 - step);
                    } else {
                        build.solid(mid - 2, y, 0, mid + 2, y + 1, step + 1);
                    }
                }
                if self.drop > 0 {
                    build.solid(mid - 2, a0 if toward < 0 else c1 + steps, 0, mid + 2, c0 - steps if toward < 0 else a1, self.drop);
                }
            }
        }
        build.doorway(hall, self.enter);
        # The ways on, each behind a seal; its button in a room.
        seals: list[Cue | None] = [None, None, None];
        for (at, port) in enumerate(self.taken) {
            number = self.taken_index[at];
            build.doorway(hall if number == 0 else arms[0 if port.face == 3 else 1], port);
            if number < 3 {
                seals[number] = port_gate(build, self.long, self.wide, port);
            }
        }
        build.touch(2.0, float(c0), 0.0, 4.0, float(c1), 6.0, True, "These doors are opened elsewhere");
        # The rooms off both sides, behind doors.
        spots: list[list[int]] = [];
        for index in range(self.rooms) {
            x = 2 + index * 7;
            if abs(x + 2 - mid) < 5 {
                continue;
            }
            spots.append([x, c0 - 6, c0 - 1, c0 - 1, 1]);
            spots.append([x, c1 + 1, c1 + 6, c1, 3]);
        }
        ranked = [spot for spot in self.order if spot < len(spots)];
        crossing = build.touch(float(mid - 2), float(c0), 0.0, float(mid + 2), float(c1), 6.0);
        loosed = build.waiting();
        crossing +>:Fires:+> loosed;
        for (rank, index) in enumerate(ranked) {
            spot = spots[index];
            x = spot[0];
            y0 = spot[1];
            y1 = spot[2];
            door_y = spot[3];
            room = build.room(x, y0, 0, x + 5, y1, self.tall - 2);
            build.widen(room, x + 1, door_y, 0, x + 4, door_y + 1, 7);
            back = float(y0) if spot[4] == 1 else float(y1);
            facing = 90.0 if spot[4] == 1 else 270.0;
            if rank == 4 {
                # A vault behind a key's door.
                build.rising_door(float(x + 1), float(door_y), 0.0, float(x + 4), float(door_y + 1), 7.0, {"key": "key_gold" if dice.chance(0.5) else "key_silver", "wait": "-1"});
                build.supply(float(x) + 2.5, float(y0 + y1) * 0.5, 0, "item_armor2");
                continue;
            }
            if rank >= 5 {
                # Rooms whose doors open as the corridor's middle is reached,
                # what waits in them coming out.
                crossing +>:Fires:+> build.opened(float(x + 1), float(door_y), 0.0, float(x + 4), float(door_y + 1), 7.0);
                build.foe(float(x) + 2.5, float(y0 + y1) * 0.5, 0, e1m6_foe(dice, self.danger, True), facing, waits=loosed);
                continue;
            }
            if rank == 3 {
                # The secret room: its door opens when shot.
                build.secret_door(float(x + 1), float(door_y), 0.0, float(x + 4), float(door_y + 1), 7.0, 3 if spot[4] == 1 else 1);
                build.secret(float(x), float(y0), 0.0, float(x + 5), float(y1), 3.0);
                build.supply(float(x) + 2.5, float(y0 + y1) * 0.5, 0, "item_artifact_super_damage");
                continue;
            }
            build.put_box({"classname": "func_door", "angle": "-1", "speed": "120", "wait": "4", "lip": "8"}, float(x + 1), float(door_y), 0.0, float(x + 4), float(door_y + 1), 7.0, door);
            build.rock_round(float(x + 1), float(door_y), 7.0, float(x + 4), float(door_y + 1), 19.0);
            if rank < 3 {
                # A button on the room's back wall opens one way on and wakes
                # what waits in the corridor; what lies in the room wakes as
                # it is entered.
                press = build.push(float(x) + 2.5, back, 1.2, spot[4]);
                seal = seals[rank];
                if seal is not None {
                    press +>:Fires:+> seal;
                }
                woken = build.waiting();
                press +>:Fires:+> woken;
                build.foe(float(mid) + 0.5, float(c0) + 2.0 + (1.0 if rank % 2 == 0 else 0.0), 0, e1m6_foe(dice, self.danger), 180.0, waits=woken);
                inside = build.touch(float(x + 1), float(y0), 0.0, float(x + 4), float(y1), 6.0);
                lurking = build.waiting();
                inside +>:Fires:+> lurking;
                build.foe(float(x) + 1.0, float(y0 + y1) * 0.5, 0, "monster_zombie", facing, waits=lurking);
                if rank == 0 {
                    press +>:Fires:+> build.summon(x + 1, c0, -9, e1m6_foe(dice, self.danger, True), float(x) + 2.5, float(c0) + 2.5, 0, 0.0);
                }
            } elif dice.chance(0.6) {
                build.foe(float(x) + 2.5, float(y0 + y1) * 0.5, 0, e1m6_foe(dice, self.danger), facing);
            } else {
                build.supply(float(x) + 2.5, float(y0 + y1) * 0.5, 0, ["item_health", "item_rockets", "item_spikes", "item_shells"][dice.below(4)]);
            }
        }
        build.foe(float(mid) + 0.5, 2.5, self.drop, e1m6_foe(dice, self.danger, True), 90.0);
        build.foe(3.5, float(c0) + 1.5, 0, "monster_knight", 0.0, patrol=[[3.5, float(c0) + 1.5], [float(self.long) - 3.5, float(c0) + 1.5]]);
    }
}

"""A long hall floored with lava, a causeway down it, ledges high on both
sides; the ledge's button opens the way on below."""
node LavaCauseway(Prefab) {
    has ledge: int = 9,
        hw: int = 16,
        tall: int = 20,
        crossed: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava causeway";
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.long = dice.between(28, 34);
        self.hw = dice.between(16, 18);
        self.wide = self.hw + 4;
        self.ledge = dice.between(12, 14);
        self.tall = self.ledge + dice.between(14, 15);
        self.crossed = dice.chance(0.5);
        self.low = -11;
        self.high = self.tall + 1;
        side = self.hw - 1;
        middle = (1 + side) // 2;
        self.enter = Port(face=2, along=float(middle), floor=0);
        self.leaves = [Port(face=0, along=float(middle), floor=0), Port(face=0, along=float(side - 2), floor=self.ledge)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hw - 1;
        middle = (1 + side) // 2;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, self.ledge);
        build.pool(4, 1, -3, self.long - 4, side, 0, 4);
        build.solid(4, middle - 2, -3, self.long - 4, middle + 2, 0);
        # The ledges along both sides high up, slabs over the lava.
        slab(build, 4, 1, self.long - 1, 5, self.ledge);
        slab(build, 4, side - 4, self.long - 1, side, self.ledge);
        # The lift up to the north ledge at the near end; sometimes a bridge
        # across between the ledges at the far end.
        lift(build, 1, side - 4, 4, side, 0, self.ledge);
        keep_box(build, hall, 1, side - 5, 5, side, self.ledge);
        keep_box(build, hall, 1, side - 5, 4, side, 0);
        if self.crossed {
            slab(build, self.long - 9, 5, self.long - 5, side - 4, self.ledge);
            keep_box(build, hall, self.long - 9, 4, self.long - 5, 6, self.ledge);
            keep_box(build, hall, self.long - 9, side - 5, self.long - 5, side - 3, self.ledge);
        }
        # The ledge's button opens the way on below.
        press = build.push(float(self.long) - 4.5, float(side), float(self.ledge) + 1.2, 3);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.floor == 0 {
                press +>:Fires:+> port_gate(build, self.long, self.wide, port);
            }
        }
        build.touch(float(self.long - 6), float(middle - 2), 0.0, float(self.long - 3), float(middle + 2), 6.0, True, "This door is opened elsewhere");
        # Spikes fly across the causeway's middle from under the south ledge.
        third = self.long // 3;
        walking = build.touch(float(third), float(middle - 2), 0.0, float(2 * third), float(middle + 2), 6.0, False);
        spike_wall(build, walking, 1, third + 1, 2 * third, 1.5, 3, False, 1);
        # Halfway along, the ledges' ogres wake and a fiend is sent in behind.
        halfway = build.touch(float(self.long // 2), float(middle - 2), 0.0, float(self.long // 2 + 2), float(middle + 2), 6.0);
        ledges = build.waiting();
        halfway +>:Fires:+> ledges;
        halfway +>:Fires:+> build.summon(1, 2, -9, e1m6_foe(dice, self.danger, True), 5.5, float(middle) + 0.5, 0, 0.0);
        closets(build, halfway, side, [x for x in [9, 14] if x + 3 <= self.long - 9], self.ledge, 1, [e1m6_foe(dice, self.danger, True)]);
        build.touch(1.0, float(middle - 2), 0.0, 3.0, float(middle + 2), 6.0, True, "Beware the lava");
        for index in range(dice.between(2, 4)) {
            at_y = 3.0 if index % 2 == 0 else float(side) - 2.0;
            build.foe(float(8 + index * 5) + 0.5, at_y, self.ledge, e1m6_foe(dice, self.danger, True), 90.0 if index % 2 == 0 else 270.0, waits=ledges);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 0.5, 0, e1m6_foe(dice, self.danger), 180.0);
        build.foe(6.5, float(side) - 2.0, self.ledge, "monster_knight", 0.0, patrol=[[6.5, float(side) - 2.0], [float(self.long) - 3.5, float(side) - 2.0]]);
        # A stash in the north wall at the ledge's height.
        stash(build, side, self.long - 8, self.ledge, 1, "item_health");
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_health");
        build.supply(6.5, 3.0, self.ledge, "item_rockets");
    }
}

"""A deep shaft, rims round it; touching the rim raises a stair out of the
shaft's floor, spikes flying across it."""
node SinkingStair(Prefab) {
    has depth: int = 15,
        rim: int = 4,
        tall: int = 11,
        lifted: bool = False,
        spiked: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Sinking stair";
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.depth = dice.between(18, 20);
        self.wide = dice.between(18, 20);
        self.long = self.rim + self.depth + 7;
        self.tall = dice.between(10, 12);
        self.lifted = dice.chance(0.5);
        self.spiked = dice.chance(0.6);
        self.low = -2 * self.depth - 2;
        self.high = self.tall + 1;
        mid = self.wide // 2;
        self.enter = Port(face=2, along=float(mid), floor=0);
        self.leaves = [
            Port(face=0, along=float(mid), floor=-self.depth),
            Port(face=1, along=float(self.long // 2 + 2), floor=0),
            Port(face=0, along=3.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        d = self.depth;
        brink = 1 + self.rim;
        shaft = build.room(1, 1, -d, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, 0);
        # The near end rock to the rim; the side rims, slabs over the shaft's
        # floor on pillars.
        build.solid(1, 1, -d, brink, self.wide - 1, 0);
        slab(build, brink, 1, self.long - 1, 5, 0);
        slab(build, brink, self.wide - 5, self.long - 1, self.wide - 1, 0);
        arcade(build, 4, brink + 3, self.long - 2, -d, -1, 4, False);
        arcade(build, self.wide - 5, brink + 3, self.long - 2, -d, -1, 4, False);
        # The stair: steps rising out of the shaft's floor beside the south
        # rim, up to the near rock, a moment after the rim is touched.
        lane = 5;
        start = brink + d - 1;
        steps = build.rising_steps(start, lane, -d, 2, d, 3);
        rim_touch = build.touch(2.0, 1.0, 0.0, float(brink), float(self.wide - 1), 6.0);
        later = build.delay(3.0);
        rim_touch +>:Fires:+> later;
        later +>:Fires:+> steps;
        keep_box(build, shaft, brink - 2, lane, brink + 1, lane + 3, 0);
        if self.spiked {
            on_stair = build.touch(float(brink), float(lane), float(-d), float(start + 1), float(lane + 3), 6.0, False);
            for index in range(0, d, 3) {
                on_stair +>:Fires:+> build.spikes(float(start - index) + 0.5, 1.2, float(-d + index + 1) + 1.5, 1);
            }
        }
        # A lift back up beside the north rim, or not.
        # Back up beside the north rim: a hoist riding up and down, and
        # sometimes a lift beside it too.
        build.train([3.0, 3.0, 1.0], [[float(self.long - 5), float(self.wide - 8), float(-d - 1)], [float(self.long - 5), float(self.wide - 8), -1.0]], 120.0, 2.0);
        if self.lifted {
            lift(build, self.long - 9, self.wide - 8, self.long - 6, self.wide - 5, -d, 0);
            keep_box(build, shaft, self.long - 10, self.wide - 9, self.long - 5, self.wide - 4, 0);
            keep_box(build, shaft, self.long - 10, self.wide - 9, self.long - 5, self.wide - 5, -d);
        }
        keep_box(build, shaft, self.long - 6, self.wide - 9, self.long - 1, self.wide - 4, 0);
        keep_box(build, shaft, self.long - 6, self.wide - 9, self.long - 1, self.wide - 5, -d);
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # A stash in the near rock at the foot, a teleporter in it back to
        # the rim.
        stash(build, brink, mid - 1, -d, 2, "item_health");
        build.teleporter(2.0, float(mid), -d, 2.5, float(mid) + 3.5, 0, 0.0);
        # What is below wakes as the stair rises; scrags in the shaft; a
        # guard walks the north rim.
        below = build.waiting();
        later +>:Fires:+> below;
        down = build.touch(float(brink), float(lane), float(-d), float(brink + 3), float(self.wide - 5), float(-d + 6));
        down +>:Fires:+> build.summon(brink + 6, self.wide - 9, -2 * d, e1m6_foe(dice, self.danger, True), float(brink) + 2.5, float(mid) + 2.5, -d, 0.0);
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long) - 3.5, float(mid) - 2.5 + float(index) * 2.5, -d, e1m6_foe(dice, self.danger, index == 0), 180.0, waits=below);
        }
        for index in range(dice.between(1, 2)) {
            build.foe(float(brink + 4 + index * 5) + 0.5, float(mid) + 0.5, -d // 2, "monster_wizard", 180.0);
        }
        build.foe(float(brink) + 1.5, float(self.wide) - 3.0, 0, "monster_knight", 0.0, patrol=[[float(brink) + 1.5, float(self.wide) - 3.0], [float(self.long) - 3.5, float(self.wide) - 3.0]]);
        build.supply(float(self.long) - 2.5, 3.0, 0, "item_rockets");
    }
}

"""A hall with a gallery round three sides; a button starts a sequence:
closets open one after another, an ogre is sent in, the way on opens."""
node ZombieGallery(Prefab) {
    has g: int = 12,
        hw: int = 16,
        tall: int = 21,
        plinth: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Zombie gallery";
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.long = dice.between(26, 30);
        self.hw = dice.between(16, 18);
        self.wide = self.hw + 4;
        self.g = dice.between(17, 18);
        self.tall = self.g + dice.between(13, 14);
        self.plinth = dice.chance(0.5);
        self.low = -9;
        self.high = self.tall + 1;
        side = self.hw - 1;
        mid = (1 + side) // 2;
        self.enter = Port(face=2, along=float(mid), floor=0);
        self.leaves = [Port(face=0, along=float(mid), floor=0), Port(face=0, along=3.0, floor=self.g), Port(face=3, along=float(self.long // 2), floor=self.g)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        side = self.hw - 1;
        mid = (1 + side) // 2;
        g = self.g;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, g);
        # The gallery: south, far end and north, on pillars.
        slab(build, 5, 1, self.long - 1, 5, g);
        slab(build, self.long - 5, 5, self.long - 1, side - 4, g);
        slab(build, 5, side - 4, self.long - 1, side, g);
        arcade(build, 4, 9, self.long - 6, 0, g - 1, 4, False);
        arcade(build, side - 4, 9, self.long - 6, 0, g - 1, 4, False);
        arcade(build, self.long - 5, 7, side - 5, 0, g - 1, 4, True);
        # The lift up to the south gallery's near end.
        lift(build, 5, 5, 8, 8, 0, g);
        keep_box(build, hall, 4, 4, 9, 9, g);
        keep_box(build, hall, 4, 5, 9, 9, 0);
        # The button: on a post on a plinth, or on the far gallery's wall.
        if self.plinth {
            px = self.long // 2 - 1;
            build.solid(px, mid - 1, 0, px + 3, mid + 2, 2);
            build.solid(px - 1, mid - 1, 0, px, mid + 2, 1);
            build.solid(px + 1, mid, 2, px + 2, mid + 1, 4);
            press = build.push(float(px + 2), float(mid) + 0.5, 2.5, 0);
        } else {
            press = build.push(float(self.long - 1), float(mid) + 0.5, float(g) + 1.2, 2);
        }
        # The sequence: closets in the north gallery's wall a second apart,
        # an ogre sent in, and the way on below at the last.
        firsts = [build.delay(1.0), build.delay(2.0), build.delay(3.0), build.delay(4.0)];
        for later in firsts {
            press +>:Fires:+> later;
        }
        starts = [x for x in [9, 14, 19, 24] if x + 3 <= self.long - 6];
        closets(build, firsts[0], side, starts[:2], g, 1, ["monster_zombie"]);
        closets(build, firsts[1], side, starts[2:], g, 1, ["monster_zombie", e1m6_foe(dice, self.danger, True)]);
        firsts[2] +>:Fires:+> build.summon(2, 2, -8, e1m6_foe(dice, self.danger, True), float(self.long // 2) + 0.5, float(mid) - 3.5, 0, 180.0);
        closets(build, firsts[2], side, starts[:2], 0, 1, [e1m6_foe(dice, self.danger, True), "monster_zombie"]);
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            if port.floor == 0 {
                firsts[3] +>:Fires:+> port_gate(build, self.long, self.wide, port);
            }
        }
        build.touch(2.0, 1.0, 0.0, 5.0, float(side), 6.0, True, "Press the button to open the way on");
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2 + 3 + index * 3) + 0.5, float(mid) + 3.5, 0, "monster_zombie", 180.0);
        }
        topped = build.touch(5.0, 1.0, float(g), 9.0, 5.0, float(g + 6));
        guard = build.waiting();
        topped +>:Fires:+> guard;
        build.foe(float(self.long) - 3.0, float(mid) + 0.5, g, e1m6_foe(dice, self.danger, True), 180.0, waits=guard);
        build.foe(float(self.long) - 3.0, float(side) - 2.5, g, e1m6_foe(dice, self.danger), 180.0, waits=guard);
        build.foe(9.5, 3.0, g, "monster_knight", 0.0, patrol=[[9.5, 3.0], [float(self.long) - 3.0, 3.0]]);
        build.supply(float(self.long) - 3.0, 3.0, g, "item_health");
        build.supply(2.5, float(side) - 2.5, 0, "item_rockets");
    }
}

"""The key on an island in lava, a bridge drawn up to it; taking the key
opens the closets and the key's own vault."""
node LavaKeyShrine(Prefab) {
    has key: str = "key_gold",
        hw: int = 16,
        shore: int = 8,
        tall: int = 17,
        shot: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Lava key shrine (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.long = dice.between(22, 25);
        self.hw = dice.between(15, 17);
        self.wide = self.hw + 8;
        self.tall = dice.between(16, 19);
        self.shot = dice.chance(0.5);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(5 + self.hw // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        y0 = 5;
        side = y0 + self.hw - 2;
        middle = y0 + self.hw // 2;
        hall = build.room(1, y0, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, 7);
        build.doorway(hall, self.enter);
        # The lava from the shore to the far wall, the island in it, the
        # bridge sunk under the lava's floor until drawn up.
        lava_x = 1 + self.shore;
        build.pool(lava_x, y0, -3, self.long - 1, side, 0, 4);
        island_x = lava_x + 3;
        build.solid(island_x, middle - 3, -3, self.long - 3, middle + 3, 0);
        bridge = build.drawn(float(lava_x), float(middle - 1), float(island_x), float(middle + 2), 0, 4);
        for y in range(middle - 1, middle + 2) {
            build.keep(hall, lava_x - 1, y, 0);
            build.keep(hall, island_x, y, 0);
        }
        if self.shot {
            press = build.push(float(self.long - 1), float(middle) + 0.5, 3.0, 2, True);
            build.touch(1.0, float(y0), 0.0, float(lava_x), float(side), 6.0, True, "Shoot the button over the lava");
        } else {
            build.solid(lava_x - 2, middle - 4, 0, lava_x - 1, middle - 3, 4);
            press = build.push(float(lava_x - 1), float(middle) - 3.5, 1.3, 0);
        }
        press +>:Fires:+> bridge;
        # A ledge over the lava along the north wall; teleporters from the
        # island up to it and back.
        slab(build, lava_x, side - 4, self.long - 1, side, 7);
        build.teleporter(float(island_x) + 1.5, float(middle) + 2.0, 0, float(self.long) - 3.5, float(side) - 2.0, 7, 180.0);
        build.teleporter(float(lava_x) + 2.5, float(side) - 2.0, 7, float(island_x) + 3.5, float(middle) - 1.5, 0, 0.0);
        # The key: taking it opens the closets in the north wall on the
        # shore, sends a foe in behind, and opens the key's own vault.
        taken = key_cue(build, self.key, float(island_x) + 4.5, float(middle) + 0.5, 0);
        closets(build, taken, side, [2, 6] if self.shore >= 8 else [2], 0, 1, [e1m6_foe(dice, self.danger, True), "monster_zombie"]);
        build.touch(1.0, float(y0), 0.0, 3.0, float(side), 6.0, True, "The key is kept by the lava");
        taken +>:Fires:+> build.summon(3, middle - 1, -8, e1m6_foe(dice, self.danger, True), 3.5, float(middle) + 0.5, 0, 0.0);
        archers = build.waiting();
        taken +>:Fires:+> archers;
        for index in range(2) {
            build.foe(float(self.long) - 3.0 - float(index) * 4.0, float(side) - 2.0, 7, e1m6_foe(dice, self.danger), 270.0, waits=archers);
        }
        # The vault beyond the south wall, behind the key's own door.
        vault = build.room(2, 1, 0, 7, 4, 7);
        build.widen(vault, 2, 4, 0, 7, y0, 6);
        build.rising_door(2.0, 4.0, 0.0, 7.0, float(y0), 6.0, {"key": self.key, "wait": "-1"});
        build.supply(4.5, 2.5, 0, "item_armor2");
        onto = build.touch(float(island_x), float(middle - 1), 0.0, float(island_x + 2), float(middle + 2), 6.0);
        keeper = build.waiting();
        onto +>:Fires:+> keeper;
        onto +>:Fires:+> build.summon(3, middle + 4, -8, "monster_wizard", float(island_x) + 2.5, float(middle) + 0.5, 4, 180.0);
        build.foe(float(island_x) + 2.5, float(middle) + 2.5, 0, e1m6_foe(dice, self.danger, True), 180.0, waits=keeper);
        build.foe(3.5, float(side) - 6.5, 0, "monster_knight", 90.0, patrol=[[3.5, float(side) - 6.5], [3.5, float(y0) + 2.5]]);
        build.supply(float(lava_x) - 2.5, float(y0) + 2.5, 0, "item_health");
    }
}

"""The end: a pillared hall, the great door, a landing and galleries over a
stair down to a lava moat, the way out beyond."""
node ChthonDoor(Prefab) {
    has key: str = "",
        door_x: int = 13,
        tall: int = 24,
        deep: int = 8,
        ridden: bool = False;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Chthon door" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E1M6;
        self.district = level_district(E1M6);
        self.door_x = dice.between(12, 14);
        self.deep = dice.between(7, 9);
        self.wide = dice.between(18, 20);
        self.tall = dice.between(24, 26);
        self.ridden = dice.chance(0.5);
        self.long = self.door_x + 5 + self.deep + 7 + dice.between(8, 10);
        self.low = -self.deep - 5;
        self.high = self.tall + 18;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        mid = self.wide // 2;
        d = self.deep;
        dx = self.door_x;
        hall = build.room(1, 1, 0, dx, self.wide - 1, self.tall, variant=dice.below(3));
        beyond = build.room(dx + 1, 1, -d, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(beyond, 0);
        build.doorway(hall, self.enter);
        pillars(build, 4, 3, dx - 2, 4, 0, self.tall, 4, [[0, mid - 3, 5, mid + 3]]);
        pillars(build, 4, self.wide - 4, dx - 2, self.wide - 3, 0, self.tall, 4, [[0, mid - 3, 5, mid + 3]]);
        # The great door: eight cells wide, sixteen lifts high, rising into
        # the wall over it; a key's, or one that rises a moment after the
        # plate before it is stepped on.
        build.widen(beyond, dx, mid - 4, 0, dx + 1, mid + 4, 16);
        plate = build.touch(float(dx - 3), float(mid - 4), 0.0, float(dx), float(mid + 4), 6.0);
        if self.key {
            build.rising_door(float(dx), float(mid - 4), 0.0, float(dx + 1), float(mid + 4), 16.0, {"key": self.key, "wait": "-1", "speed": "60"});
        } else {
            later = build.delay(2.0);
            plate +>:Fires:+> later;
            later +>:Fires:+> build.opened(float(dx), float(mid - 4), 0.0, float(dx + 1), float(mid + 4), 16.0);
        }
        # Beyond: a landing, galleries along both walls over the stair down
        # to the moat's floor.
        land_x = dx + 5;
        build.solid(dx + 1, 1, -d, land_x, self.wide - 1, 0);
        stair_x = land_x + d - 1;
        stair(build, stair_x, mid - 2, -d, 2, d, 4);
        moat_x = land_x + d + 1;
        slab(build, land_x, 1, moat_x, 5, 0);
        slab(build, land_x, self.wide - 5, moat_x, self.wide - 1, 0);
        keep_box(build, beyond, land_x - 1, mid - 3, land_x + 1, mid + 3, 0);
        # The moat: lava, crossed by a stone way, or by a riding platform past
        # a gap in the way.
        far_x = moat_x + 7;
        build.pool(moat_x, 1, -d - 3, far_x, self.wide - 1, -d, 4);
        if self.ridden {
            build.solid(moat_x, mid - 2, -d - 3, moat_x + 3, mid + 2, -d);
            build.solid(moat_x + 4, mid - 2, -d - 3, far_x, mid + 2, -d);
            build.train([3.0, 3.0, 1.0], [[float(moat_x), float(mid + 3), float(-d - 1)], [float(far_x - 3), float(mid + 3), float(-d - 1)]], 80.0, 2.0);
            for across in range(3) {
                build.keep(beyond, moat_x - 1, mid + 3 + across, -d);
                build.keep(beyond, far_x, mid + 3 + across, -d);
            }
        } else {
            build.solid(moat_x, mid - 2, -d - 3, far_x, mid + 2, -d);
        }
        for y in range(mid - 2, mid + 2) {
            build.keep(beyond, moat_x - 1, y, -d);
            build.keep(beyond, far_x, y, -d);
            build.keep(beyond, moat_x + 2, y, -d);
            build.keep(beyond, moat_x + 4, y, -d);
        }
        build.way_out(float(self.long) - 4.0, float(mid), -d);
        brim = build.touch(float(moat_x - 2), float(mid - 2), float(-d), float(moat_x), float(mid + 2), float(-d + 6));
        brim +>:Fires:+> build.summon(4, mid - 1, -9, e1m6_foe(dice, self.danger, True), float(land_x) + 1.5, float(mid) + 0.5, 0, 180.0);
        # The stash under the landing; the guards on the far bank counted as
        # they fall to a cache in the far wall.
        stash(build, land_x, mid - 7, -d, 2, "item_armor2");
        both = build.tally(2, "A cache has opened");
        for index in range(2) {
            foe_cue(build, float(self.long) - 6.5, float(mid) - 4.5 + float(index) * 9.0, -d, e1m6_foe(dice, self.danger, True), 180.0) +>:Fires:+> both;
        }
        build.solid(self.long - 5, 1, -d, self.long - 1, 5, -d + 7);
        cache = build.room(self.long - 4, 1, -d, self.long - 1, 4, -d + 6);
        build.widen(cache, self.long - 4, 4, -d, self.long - 1, 5, -d + 5);
        both +>:Fires:+> build.opened(float(self.long - 4), 4.0, float(-d), float(self.long - 1), 5.0, float(-d + 5));
        build.supply(float(self.long) - 2.5, 2.5, -d, "item_artifact_super_damage");
        # Stepping on the plate wakes the galleries' archers.
        archers = build.waiting();
        plate +>:Fires:+> archers;
        for y in [3.0, float(self.wide) - 3.0] {
            build.foe(float(moat_x) - 1.5, y, 0, e1m6_foe(dice, self.danger), 0.0, waits=archers);
        }
        entering = build.touch(2.0, float(mid - 3), 0.0, 5.0, float(mid + 3), 6.0);
        hall_foes = build.waiting();
        entering +>:Fires:+> hall_foes;
        for index in range(dice.between(2, 3)) {
            build.foe(float(dx) - 3.5 - float(index % 2) * 3.0, 6.5 + float(index) * 3.5, 0, e1m6_foe(dice, self.danger, index == 0), 180.0, waits=hall_foes);
        }
        build.foe(3.5, float(mid) + 0.5, 0, "monster_knight", 0.0, patrol=[[3.5, float(mid) + 0.5], [float(dx) - 4.5, float(mid) + 0.5]]);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, 0, "item_rockets");
    }
}

"""e1m6's stretches: [name, role]."""
glob E1M6_STRETCHES: list[list[str]] = [
         ["overlook", "start"],
         ["causeway", "flow"],
         ["doors", "hub"],
         ["doors", "flow"],
         ["stair", "flow"],
         ["gallery", "flow"],
         ["shrine", "keyroom"],
         ["door", "end"],
         ["door", "gate"]
     ];

"""One of e1m6's stretches by its name."""
def make_e1m6(name: str, key: str) -> Prefab {
    if name == "overlook" {
        return LavaOverlook();
    }
    if name == "causeway" {
        return LavaCauseway();
    }
    if name == "doors" {
        return DoorMaze();
    }
    if name == "stair" {
        return SinkingStair();
    }
    if name == "gallery" {
        return ZombieGallery();
    }
    if name == "shrine" {
        return LavaKeyShrine(key=key if key else "key_gold");
    }
    return ChthonDoor(key=key);
}
