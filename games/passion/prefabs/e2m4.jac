"""Prefabs drawn from e2m4, the Ebon Fortress: a black fortress over a moat,
barred gates that "open elsewhere", a crypt of zombies under a gallery
whose walls open on the dead, platforms riding across a chasm when a
button sets them going, a hall of galleries one over another, the silver
key caged high on a ledge, and the way out behind bars that open when the
three switches are shot. Raised in e2m4's own palette.

- `MoatGate`: the start. A yard under the sky, a moat across it (swum, or
  crossed by a causeway), the fortress wall beyond with its gate barred
  ("These bars open elsewhere..."). The bars sink when a button is used:
  pushed on the wall-walk (up a stair along the wall's face, a lift, or a
  ramp and a bridge high over the moat) or shot on the wall's face. Scrags
  are brought in behind the player as the bars go down (e2m4's teleported
  scrags), ogres on the wall wake as the player lands on the far shore, a
  knight walks the wall-walk, and the moat hides a flooded grotto (a
  secret) and the yard a stash behind a wall that opens when shot.
- `CryptUndercroft`: a gallery round (or along) a well looking down into a
  crypt, a stair or a lift (or both) down; ways on from both floors (a
  hub as well). Walking into the crypt opens its walls on the dead behind
  them (e2m4's secret walls fired by a touch) and brings one in behind;
  a knight walks the gallery; a stash behind a wall on the gallery opens
  when shot.
- `TrainChasm`: a chasm between two ledges, its floor far below (a pool,
  or dry), a platform waiting at the near ledge that a button (pushed, or
  shot across the chasm) sets riding over to the far one (e2m4's trains);
  in some a stair up from the far ledge to a gallery over it and a second
  platform riding back high over the chasm to a gallery over the way in.
  A lift climbs back out of the chasm; a niche under the near ledge opens
  when shot.
- `KeepShaft`: a tall shaft, a lift (or a stair up the wall) to a ledge
  along one wall, a lift on from it to a ledge high along the next, over
  the first; scrags wake as the player climbs, the high ledge's keeper as
  the player comes onto it, and a stretch of its edge is left open to
  drop back down from.
- `EbonHall`: a hall of two galleries, the upper over the lower or along
  the next wall, a stair or a lift to each (a hub), a pool sunk in the
  floor in some. A door on the floor
  will not open ("I don't think so...") until a button high on the wall
  is shot; scrags are brought in as the player crosses the floor; knights
  walk the floor and an ogre the gallery.
- `SilverKeep`: the key room. A pit of lava crossed pillar to pillar or by
  a bridge drawn up out of it, a ledge beyond ridden up to by a lift or
  climbed by a stair, the key in a cage on it behind bars opened by a
  button elsewhere; taking it opens the closets below.
- `SwitchVault`: the end. A balcony high over a hall, the way out behind
  bars at the hall's far end that sink only when the three switches on
  its walls are shot (e2m4's "Shoot the switches..." counter); a lift or a
  stair down, a channel of lava across the floor in some; what waits on
  the floor wakes as the player comes down, and a fiend is brought in. As
  a gate, a key's bars at the balcony's back."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising, Cue, Fires, RockWant }
import from ..kits { level_district, kit_of }
import from ..space { Space }
import from .roster { FoeMix }
import from .common { stair, key_item, lift }

glob E2M4: str = "q1:e2m4";

"""e2m4's foes: the dead and ogres, fiends and hell knights deeper in,
scrags in the air."""
glob E2M4_FOES: FoeMix = FoeMix(light=["monster_zombie", "monster_ogre", "monster_zombie", "monster_knight"], strong=["monster_ogre"], heavy_light=["monster_ogre", "monster_ogre", "monster_knight"], heavy_strong=["monster_demon1", "monster_hell_knight"], flying="monster_wizard");

"""Bars across a way: a door of the prefab's cells x0..x1, y0..y1 from lift
`z`, `high` lifts tall, that sinks into the floor when its cue fires
(e2m4's bars that "open elsewhere"), rock under it to sink into. A `key`
makes it a key's door, opened by touch with the key."""
def e2m4_bars(build: Raising, x0: float, y0: float, x1: float, y1: float, z: int, high: int, message: str, key: str = "") -> Cue {
    fields = {"classname": "func_door", "angle": "-2", "speed": "60", "wait": "-1", "lip": "2"};
    if message {
        fields["message"] = message;
    }
    if key {
        fields["key"] = key;
    }
    build.put_box(fields, x0, y0, float(z), x1, y1, float(z + high), kit_of(build.district).door);
    corners = build.box_units(x0, y0, float(z - high), x1, y1, float(z));
    build.rocks.append(RockWant(low=corners[0], high=corners[1]));
    build.casting.doors += 1;
    return build.cue([fields], "bars");
}

"""A stretch of wall that opens when its cue fires (e2m4's secret walls
opened by a touch): a box of the prefab's cells drawn as the wall that
slides aside along it, then back the way `direction` goes (0 +x ... 3 -y),
rock in the wall about it to open into."""
def e2m4_wall_opens(build: Raising, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, direction: int) -> Cue {
    fields = {"classname": "func_door_secret", "angle": str(build.facing(direction)), "sounds": "1", "spawnflags": "1"};
    build.put_box(fields, x0, y0, z0, x1, y1, z1, kit_of(build.district).wall);
    reach = max(x1 - x0, y1 - y0) + 1.0;
    if direction == 1 {
        build.rock_round(x0 - reach, y0, z0, x1 + reach, y1 + 2.0, z1 + 1.0);
    } elif direction == 3 {
        build.rock_round(x0 - reach, y0 - 2.0, z0, x1 + reach, y1, z1 + 1.0);
    } elif direction == 0 {
        build.rock_round(x0, y0 - reach, z0, x1 + 2.0, y1 + reach, z1 + 1.0);
    } else {
        build.rock_round(x0 - 2.0, y0 - reach, z0, x1, y1 + reach, z1 + 1.0);
    }
    return build.cue([fields], "wall");
}

"""A key lying on a floor as a cue: taking it fires what it is wired to."""
def e2m4_key(build: Raising, key: str, x: float, y: float, z: int) -> Cue {
    fields = {"classname": key_item(key), "asset_game": "q1"};
    build.put_at(fields, x, y, z);
    return build.cue([fields], "key");
}

"""Water across the prefab's cells x0..x1, y0..y1, `depth` lifts deep under
lift `rim`, a lift under its rim, and steps up out of it against both
shores at its low-y end (and at its high-y end too, when `both`: for water
split by a causeway). Answers its space."""
def e2m4_moat(build: Raising, x0: int, x1: int, y0: int, y1: int, depth: int, rim: int = 0, both: bool = False) -> Space {
    bottom = rim - depth;
    space = build.room(x0, y0, bottom, x1, y1, rim);
    for z in range(bottom, rim - 1) {
        for y in range(y0, y1) {
            for x in range(x0, x1) {
                build.liquid(x, y, z, 2);
            }
        }
    }
    for step in range(depth) {
        build.solid(x0, y0 + step, bottom, x0 + 2, y0 + step + 1, bottom + step + 1);
        build.solid(x1 - 2, y0 + step, bottom, x1, y0 + step + 1, bottom + step + 1);
        if both {
            build.solid(x0, y1 - step - 1, bottom, x0 + 2, y1 - step, bottom + step + 1);
            build.solid(x1 - 2, y1 - step - 1, bottom, x1, y1 - step, bottom + step + 1);
        }
    }
    return space;
}

"""A stash behind a stretch of wall that opens when shot: a closet of the
prefab's cells x0..x1, y0..y1 (two cells across) on lift `z`, the wall
before it two cells thick on its `face` side (0 +x ... 3 -y), a secret
when found, and `item` in it. The wall slides aside along itself, then
back, into rock kept to the wall it stands in."""
def e2m4_stash(build: Raising, x0: int, y0: int, x1: int, y1: int, z: int, face: int, item: str) {
    build.room(x0, y0, z, x1, y1, z + 4);
    door = [float(x1), float(y0), float(x1 + 2), float(y1)];
    back = 2;
    if face == 2 {
        door = [float(x0 - 2), float(y0), float(x0), float(y1)];
        back = 0;
    } elif face == 1 {
        door = [float(x0), float(y1), float(x1), float(y1 + 2)];
        back = 3;
    } elif face == 3 {
        door = [float(x0), float(y0 - 2), float(x1), float(y0)];
        back = 1;
    }
    build.put_box({"classname": "func_door_secret", "angle": str(build.facing(back)), "sounds": "1"}, door[0], door[1], float(z), door[2], door[3], float(z + 4), kit_of(build.district).wall);
    span = door[3] - door[1] if face % 2 == 0 else door[2] - door[0];
    if face % 2 == 0 {
        build.rock_round(min(door[0], float(x0)), door[1] - span, float(z), max(door[2], float(x1)), door[3] + span, float(z + 5));
    } else {
        build.rock_round(door[0] - span, min(door[1], float(y0)), float(z), door[2] + span, max(door[3], float(y1)), float(z + 5));
    }
    build.secret(float(x0), float(y0), float(z), float(x1), float(y1), float(z + 3));
    build.supply(float(x0 + x1) * 0.5, float(y0 + y1) * 0.5, z, item);
}

"""Closets beyond a wall: one three cells wide at each of `xs` past the
cell line y = `side` (on its +y side), their doors in the wall's cells
rising when `opens` fires, on lift `floor`, a foe of `kinds` (in turn) in
each waiting on `wake`."""
def e2m4_closets(build: Raising, xs: list[int], side: int, floor: int, opens: Cue, wake: Cue, kinds: list[str]) {
    for (index, at) in enumerate(xs) {
        closet = build.room(at, side + 1, floor, at + 3, side + 4, floor + 7);
        build.widen(closet, at, side, floor, at + 3, side + 1, floor + 6);
        fields = {"wait": "-1"};
        build.rising_door(float(at), float(side), float(floor), float(at + 3), float(side + 1), float(floor + 6), fields);
        opens +>:Fires:+> build.cue([fields], "door");
        build.foe(float(at) + 1.5, float(side) + 2.5, floor, kinds[index % len(kinds)], 270.0, waits=wake);
    }
}

"""The start: a yard, a moat, the fortress wall and its barred gate."""
node MoatGate(Prefab) {
    has wall: int = 10,
        tall: int = 24,
        moat_x: int = 14,
        moat_w: int = 5,
        wall_x: int = 26,
        gate_y: int = 16,
        climb: int = 0,
        causeway: bool = False,
        shot: bool = False,
        grotto: bool = True,
        stash: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Moat gate";
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.wall = dice.between(10, 12);
        self.climb = dice.below(3);
        self.causeway = dice.chance(0.4);
        self.shot = dice.chance(0.5);
        self.grotto = dice.chance(0.7);
        self.stash = dice.chance(0.5);
        self.moat_x = self.wall + 4;
        self.moat_w = dice.between(8, 10);
        self.wall_x = self.moat_x + self.moat_w + dice.between(6, 7);
        self.long = self.wall_x + 8;
        self.wide = dice.between(22, 24);
        self.tall = self.wall + dice.between(12, 14);
        self.gate_y = self.wide - 6;
        self.low = -11;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=0);
        self.leaves = [Port(face=0, along=float(self.gate_y), floor=0), Port(face=0, along=5.0, floor=self.wall), Port(face=1, along=float(self.long - 4), floor=self.wall)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        top = self.wall;
        wx = self.wall_x;
        gy = self.gate_y;
        mx0 = self.moat_x;
        mx1 = mx0 + self.moat_w;
        middle = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        build.level(yard, top);
        e2m4_moat(build, mx0, mx1, 1, self.wide - 1, 10);
        if self.causeway {
            build.solid(mx0, gy - 2, -1, mx1, gy + 2, 0);
            for y in range(gy - 2, gy + 2) {
                build.keep(yard, mx0 - 1, y, 0);
                build.keep(yard, mx1, y, 0);
            }
        }
        # The fortress wall, the passage through it behind the bars.
        build.solid(wx, 1, 0, self.long - 1, self.wide - 1, top);
        build.widen(yard, wx, gy - 2, 0, self.long - 1, gy + 2, 8);
        # Guardrooms in the wall's thickness, a step up off the passage, a
        # second a step on.
        guard_room = build.room(wx + 2, gy - 8, 1, self.long - 2, gy - 3, 7);
        build.widen(guard_room, wx + 2, gy - 3, 1, wx + 5, gy - 2, 7);
        back_room = build.room(wx + 2, gy - 13, 2, self.long - 2, gy - 9, 8);
        build.widen(back_room, wx + 2, gy - 9, 2, wx + 5, gy - 8, 7);
        build.supply(float(wx) + 3.5, float(gy) - 11.0, 2, "item_shells");
        # The way up onto the wall-walk: a stair up the wall's face, a lift,
        # or a ramp up the yard's side and a bridge high over the moat.
        arrive = [top - 2, top + 3];
        if self.climb == 0 {
            stair(build, wx - 3, 1, 0, 1, top, 3);
            for y in range(top - 2, top + 2) {
                build.keep(yard, wx, y, top);
            }
        } elif self.climb == 1 {
            arrive = [1, 7];
            lift(build, wx - 3, 2, wx, 5, 0, top);
            for y in range(1, 6) {
                build.keep(yard, wx, y, top);
                build.keep(yard, wx - 4, y, 0);
            }
        } else {
            arrive = [1, 6];
            stair(build, mx0 - top, 1, 0, 0, top, 3);
            build.solid(mx0, 1, top - 1, wx, 4, top);
            for y in range(1, 4) {
                for x in [mx0 - 1, mx0, wx - 1, wx] {
                    build.keep(yard, x, y, top);
                }
            }
        }
        # Merlons along the wall-walk's edge, clear of where the way up
        # comes onto it.
        for y in range(2, self.wide - 2, 2) {
            if y < arrive[0] or y >= arrive[1] {
                build.solid(wx, y, top, wx + 1, y + 1, top + 2);
            }
        }
        for port in self.taken {
            build.doorway(yard, port);
        }
        # The bars across the gate's passage, and the button that sinks
        # them: shot on the wall's face beside the gate, or pushed on a post
        # on the wall-walk.
        bars = e2m4_bars(build, float(wx), float(gy - 2), float(wx + 1), float(gy + 2), 0, 8, "These bars open elsewhere...");
        bx = self.long - 3;
        if not self.shot {
            build.solid(bx, middle - 1, top, bx + 1, middle, top + 3);
        }
        press = build.push(float(wx), float(gy) + 3.5, 3.0, 2, True) if self.shot else build.push(float(bx), float(middle) - 0.5, float(top) + 1.2, 2);
        press +>:Fires:+> bars;
        # What waits by the gate wakes as the bars go down, and scrags are
        # brought in over the moat behind the player.
        wake = build.waiting();
        press +>:Fires:+> wake;
        for index in range(dice.between(1, 2)) {
            build.foe(float(self.long) - 3.5 - float(index) * 2.0, float(gy) - 0.5 + float(index), 0, E2M4_FOES.pick(dice, self.danger, index == 0), 180.0, waits=wake);
        }
        late = build.delay(1.5);
        press +>:Fires:+> late;
        for index in range(dice.between(1, 2)) {
            late +>:Fires:+> build.summon(2, 3 + index * 5, -8, "monster_wizard", float(mx1) + 2.5, float(middle) - 2.5 + float(index) * 4.0, 2, 180.0);
        }
        # Ogres on the wall-walk wake as the player lands on the far shore;
        # a knight walks its length.
        shore = build.touch(float(mx1), 1.0, 0.0, float(wx), float(self.wide - 1), 6.0);
        guard = build.waiting();
        shore +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(wx) + 2.5, float(self.wide) - 4.5 - float(index) * 6.0, top, "monster_ogre", 180.0, waits=guard);
        }
        build.foe(float(wx) + 4.5, 3.5, top, "monster_knight", 90.0, patrol=[[float(wx) + 4.5, 3.5], [float(wx) + 4.5, float(self.wide) - 3.5]]);
        # The flooded grotto under the far shore, a secret at its end.
        if self.grotto {
            build.room(mx1, 11, -8, mx1 + 4, 14, -3);
            for z in range(-8, -3) {
                for y in range(11, 14) {
                    for x in range(mx1, mx1 + 4) {
                        build.liquid(x, y, z, 2);
                    }
                }
            }
            build.secret(float(mx1 + 1), 11.0, -8.0, float(mx1 + 4), 14.0, -3.0);
            build.supply(float(mx1) + 2.5, 12.5, -8, "item_artifact_super_damage");
        }
        # A stash in a buttress of the yard, behind a wall that opens when
        # shot.
        if self.stash {
            build.solid(1, self.wide - 6, 0, 8, self.wide - 1, 8);
            e2m4_stash(build, 3, self.wide - 4, 5, self.wide - 1, 0, 3, "item_armor2");
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "item_shells");
        build.foe(float(mx0) - 2.5, float(middle) + 2.5, 0, E2M4_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(mx0 + mx1) * 0.5, float(middle) + 0.5, 6, "monster_wizard", 180.0);
        build.supply(float(wx) - 1.5, float(gy) + 3.5, 0, "item_health");
        build.supply(float(self.long) - 3.5, float(self.wide) - 3.5, top, "item_rockets");
    }
}

"""A gallery round (or along) a well over a crypt, a way down; the crypt's
walls open on the dead."""
node CryptUndercroft(Prefab) {
    has gallery: int = 9,
        tall: int = 20,
        ring: bool = True,
        down: int = 0,
        stash: bool = True;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Crypt undercroft";
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.long = dice.between(26, 30);
        self.wide = dice.between(20, 22);
        self.gallery = dice.between(9, 10);
        self.tall = self.gallery + dice.between(13, 16);
        self.ring = dice.chance(0.5);
        self.down = dice.below(3);
        self.stash = dice.chance(0.6);
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=self.gallery);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=0, along=4.0, floor=self.gallery),
            Port(face=1, along=4.0, floor=self.gallery),
            Port(face=3, along=float(self.long - 6), floor=0)
        ];
        visitor.place(self);
    }

    """The well's box [x0, y0, x1, y1]: in the middle with the gallery round
    it, or open to the far wall with the gallery along two sides and a walk
    along the third."""
    def opening -> list[int] {
        if self.ring {
            return [6, 6, self.long - 6, self.wide - 6];
        }
        return [6, 8, self.long - 1, self.wide - 4];
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        g = self.gallery;
        middle = self.wide // 2;
        hall = build.room(1, 1, g - 1, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        crypt = build.room(1, 4, 0, self.long - 1, self.wide - 4, g - 1, variant=dice.below(3));
        build.level(hall, g);
        build.level(crypt, 0);
        # The way out through the crypt's side wall.
        build.widen(crypt, self.long - 8, 1, 0, self.long - 4, 4, 8);
        # The gallery's floor over the crypt, the well cut through it.
        well = self.opening();
        build.solid(1, 1, g - 1, self.long - 1, self.wide - 1, g);
        build.widen(hall, well[0], well[1], g - 1, well[2], well[3], g);
        if self.ring {
            for corner in [[well[0] - 1, well[1] - 1], [well[2], well[1] - 1], [well[0] - 1, well[3]], [well[2], well[3]]] {
                build.solid(corner[0], corner[1], 0, corner[0] + 1, corner[1] + 1, g - 1);
            }
        } else {
            for x in range(well[0] + 4, well[2] - 2, 5) {
                build.solid(x, well[1] - 1, 0, x + 1, well[1], g - 1);
            }
        }
        # The way down: a stair down along the well's near side, a lift at
        # its near corner, or both (the lift at its far corner).
        if self.down != 1 {
            stair(build, well[0] + g - 1, well[1], 0, 2, g, 3);
            for y in range(well[1], well[1] + 3) {
                build.keep(hall, well[0] - 1, y, g);
            }
        }
        if self.down == 1 {
            lift(build, well[0], well[1], well[0] + 3, well[1] + 3, 0, g);
            for y in range(well[1], well[1] + 3) {
                build.keep(hall, well[0] - 1, y, g);
                build.keep(crypt, well[0] + 3, y, 0);
            }
        } elif self.down == 2 {
            lx = well[2] - 3 if self.ring else well[0] + g + 2;
            lift(build, lx, well[3] - 3, lx + 3, well[3], 0, g);
            for x in range(lx, lx + 3) {
                build.keep(hall, x, well[3], g);
                build.keep(crypt, x, well[3] - 4, 0);
            }
        }
        # A stretch of the well's far rim without a railing, to drop from.
        rim = well[0] + (well[2] - well[0]) // 2;
        for x in range(rim, rim + 3) {
            build.keep(hall, x, well[3], g);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(crypt if port.floor == 0 else hall, port);
        }
        # Walking into the crypt opens its walls on the dead behind them,
        # and something is brought in behind the player.
        into = build.touch(float(rim - 1), float(middle - 2), 0.0, float(rim + 3), float(middle + 2), 6.0);
        stirred = build.waiting();
        into +>:Fires:+> stirred;
        south_x = 7;
        north_x = 13 + dice.below(3);
        build.room(south_x, 1, 0, south_x + 3, 3, 6);
        into +>:Fires:+> e2m4_wall_opens(build, float(south_x), 3.0, 0.0, float(south_x + 3), 4.0, 6.0, 3);
        build.foe(float(south_x) + 1.5, 2.0, 0, E2M4_FOES.pick(dice, self.danger, True), 90.0, waits=stirred);
        build.room(north_x, self.wide - 3, 0, north_x + 3, self.wide - 1, 6);
        into +>:Fires:+> e2m4_wall_opens(build, float(north_x), float(self.wide - 4), 0.0, float(north_x + 3), float(self.wide - 3), 6.0, 1);
        build.foe(float(north_x) + 1.5, float(self.wide) - 2.0, 0, E2M4_FOES.pick(dice, self.danger), 270.0, waits=stirred);
        for index in range(dice.between(2, 3)) {
            build.foe(float(well[0] + 2 + index * 3) + 0.5, float(well[3]) - 1.5, 0, "monster_zombie", 270.0, waits=stirred);
        }
        late = build.delay(2.0);
        into +>:Fires:+> late;
        late +>:Fires:+> build.summon(2, 6, -8, E2M4_FOES.pick(dice, self.danger, True), float(well[0]) + 1.5, float(middle) + 0.5, 0, 0.0);
        # Burial vaults a step up off the crypt's floor, along both its walls.
        for x in range(12, self.long - 9, 4) {
            build.room(x, 1, 1, x + 3, 4, 7);
        }
        for x in range(3, self.long - 3, 4) {
            if x + 3 <= north_x or x >= north_x + 3 {
                build.room(x, self.wide - 4, 1, x + 3, self.wide - 1, 7);
            }
        }
        # A knight walks the gallery's far side; an ogre keeps its end.
        build.foe(3.5, float(self.wide) - 2.5, g, "monster_knight", 0.0, patrol=[[3.5, float(self.wide) - 2.5], [float(self.long) - 3.5, float(self.wide) - 2.5]]);
        build.foe(float(self.long) - 3.5, 6.5, g, E2M4_FOES.pick(dice, self.danger, True), 180.0);
        if self.stash {
            build.solid(1, 1, g, 8, 6, g + 8);
            e2m4_stash(build, 3, 2, 6, 4, g, 0, "item_artifact_super_damage");
        }
        build.supply(float(self.long) - 2.5, float(middle) + 0.5, 0, "item_health");
        build.supply(2.5, float(self.wide) - 2.5, g, "item_spikes");
    }
}

"""A chasm between two ledges, platforms set riding across it by a
button."""
node TrainChasm(Prefab) {
    has ledge: int = 12,
        near: int = 7,
        far: int = 8,
        upper: bool = False,
        shot: bool = False,
        wet: bool = True,
        nook: bool = True,
        lane: int = 4,
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Train chasm";
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.long = dice.between(30, 34);
        self.wide = dice.between(16, 20);
        self.ledge = dice.between(11, 13);
        self.upper = dice.chance(0.5);
        self.shot = dice.chance(0.4);
        self.wet = dice.chance(0.75);
        self.nook = dice.chance(0.6);
        self.lane = dice.between(1, self.wide - 9);
        self.tall = self.ledge + (19 if self.upper else 11);
        self.low = -9;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=self.ledge);
        if self.upper {
            self.leaves = [
                Port(face=0, along=float(self.wide - 4), floor=self.ledge),
                Port(face=1, along=float(self.long - 4), floor=self.ledge),
                Port(face=3, along=4.0, floor=self.ledge + 9),
                Port(face=3, along=float(self.near + 3), floor=0)
            ];
        } else {
            self.leaves = [
                Port(face=0, along=float(self.wide // 2), floor=self.ledge),
                Port(face=1, along=float(self.long - 4), floor=self.ledge),
                Port(face=3, along=float(self.near + 3), floor=0)
            ];
        }
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        h = self.ledge;
        u = h + 9;
        nx = self.near;
        fx = self.long - 1 - self.far;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, h);
        build.solid(1, 1, 0, nx, self.wide - 1, h);
        build.solid(fx, 1, 0, self.long - 1, self.wide - 1, h);
        # The chasm's floor: a strip at the near ledge's foot, and beyond it
        # a pool (or more floor).
        if self.wet {
            build.pool(nx + 6, 1, -8, fx, self.wide - 1, 0, 2);
        }
        # The lift back up out of the chasm, beside the platform's lane.
        lane = self.lane;
        ly = lane + 5;
        lift(build, nx, ly, nx + 3, ly + 3, 0, h);
        for y in range(ly, ly + 3) {
            build.keep(hall, nx - 1, y, h);
            build.keep(hall, nx + 3, y, 0);
        }
        # The platform waiting at the near ledge, and the button that sets
        # it riding over to the far one.
        ride = build.train([3.0, 4.0, 1.0], [[float(nx), float(lane), float(h - 1)], [float(fx - 3), float(lane), float(h - 1)]], 120.0, 2.0, True);
        for y in range(lane, lane + 4) {
            build.keep(hall, nx - 1, y, h);
            build.keep(hall, fx, y, h);
        }
        post_y = self.wide - 3 if lane < 4 else 1;
        if not self.shot {
            build.solid(nx - 2, post_y, h, nx - 1, post_y + 1, h + 3);
        }
        press = build.push(float(nx + fx) * 0.5, 1.0, float(h) + 4.0, 1, True) if self.shot else build.push(float(nx - 2), float(post_y) + 0.5, float(h) + 1.2, 2);
        press +>:Fires:+> ride;
        if self.upper {
            build.level(hall, u);
            # A stair up the far ledge's back to a gallery over it, a gallery
            # over the way in, and a second platform riding between them.
            stair(build, self.long - 4, 1, h, 1, 9, 3);
            build.solid(fx, 10, u - 1, self.long - 1, self.wide - 1, u);
            build.solid(1, 1, u - 1, nx, self.wide - 1, u);
            for x in range(self.long - 4, self.long - 1) {
                build.keep(hall, x, 10, u);
            }
            high_lane = self.wide - 5;
            press +>:Fires:+> build.train([3.0, 4.0, 1.0], [[float(nx), float(high_lane), float(u - 1)], [float(fx - 3), float(high_lane), float(u - 1)]], 120.0, 2.0, True);
            for y in range(high_lane, high_lane + 4) {
                build.keep(hall, nx - 1, y, u);
                build.keep(hall, fx, y, u);
            }
            build.foe(float(fx) + 2.5, float(self.wide) - 2.5, u, E2M4_FOES.pick(dice, self.danger, True), 180.0);
            build.supply(2.5, 2.5, u, "item_health");
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
        }
        # What keeps the far ledge wakes as the platform sets out; a knight
        # walks the ledge; scrags hang over the chasm.
        guard = build.waiting();
        press +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            build.foe(float(fx) + 2.5 + float(index), float(self.wide) - 3.5 - float(index) * 3.0, h, E2M4_FOES.pick(dice, self.danger, True), 180.0, waits=guard);
        }
        build.foe(float(fx) + 1.5, 2.5, h, "monster_knight", 90.0, patrol=[[float(fx) + 1.5, 2.5], [float(fx) + 1.5, float(self.wide) - 2.5]]);
        for index in range(dice.between(2, 3)) {
            build.foe(float(nx + 4 + index * 5) + 0.5, float(self.wide // 2) + 0.5, h + 3, "monster_wizard", 180.0);
        }
        build.foe(float(nx) + 2.5, float(ly) - 1.5, 0, E2M4_FOES.pick(dice, self.danger), 0.0);
        # A chamber in the near ledge's foot, a step up off the chasm's floor.
        room_y = 4 if ly >= 10 else self.wide - 7;
        build.room(2, room_y, 1, nx, room_y + 5, 8);
        build.supply(4.5, float(room_y) + 2.5, 1, "item_shells");
        # A niche under the near ledge, behind a wall that opens when shot.
        if self.nook {
            e2m4_stash(build, nx - 4, 1, nx - 2, 3, 0, 0, "item_artifact_envirosuit");
        }
        build.supply(2.5, float(self.wide) - 2.5, h, "item_rockets");
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, h, "item_health");
        build.supply(float(nx) + 4.5, float(self.wide) - 2.5, 0, "item_spikes");
    }
}

"""A tall shaft: a lift (or a stair) to a ledge along one wall, a lift on
to a ledge high along the next."""
node KeepShaft(Prefab) {
    has first: int = 9,
        second: int = 18,
        stairs: bool = False,
        tall: int = 27;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Keep shaft";
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.long = dice.between(18, 20);
        self.wide = dice.between(18, 20);
        self.first = dice.between(8, 9);
        self.stairs = dice.chance(0.5);
        self.second = self.first + 9;
        self.tall = self.second + 13;
        self.low = -8;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=5.0, floor=0);
        self.leaves = [
            Port(face=0, along=float(self.wide - 4), floor=self.second),
            Port(face=1, along=5.0, floor=self.first),
            Port(face=3, along=float(self.long - 4), floor=self.second),
            Port(face=3, along=5.0, floor=0) if self.stairs else Port(face=0, along=5.0, floor=0)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        a = self.first;
        b = self.second;
        shaft = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(shaft, a);
        build.level(shaft, b);
        # The first ledge along the north wall, ridden up to by a lift at its
        # west end or climbed by a stair up the east wall under the second.
        build.solid(1, self.wide - 6, a - 1, self.long - 1, self.wide - 1, a);
        if self.stairs {
            stair(build, self.long - 4, self.wide - 6 - a, 0, 1, a, 3);
            for x in range(self.long - 4, self.long - 1) {
                build.keep(shaft, x, self.wide - 6, a);
            }
        } else {
            lift(build, 2, self.wide - 9, 5, self.wide - 6, 0, a);
            for x in range(2, 5) {
                build.keep(shaft, x, self.wide - 6, a);
                build.keep(shaft, x, self.wide - 10, 0);
            }
        }
        # The second ledge along the east wall, over the first's end, a lift
        # up to it from the first; a stretch of its edge open to drop from.
        build.solid(self.long - 6, 1, b - 1, self.long - 1, self.wide - 1, b);
        lift(build, self.long - 9, self.wide - 5, self.long - 6, self.wide - 2, a, b);
        for y in range(self.wide - 5, self.wide - 2) {
            build.keep(shaft, self.long - 6, y, b);
            build.keep(shaft, self.long - 10, y, a);
        }
        for y in range(4, 8) {
            build.keep(shaft, self.long - 6, y, b);
        }
        # A pool at the shaft's foot, the water under the ledges' drop.
        build.pool(6, 5, -7, self.long - 5, self.wide - 10, 0, 2);
        # Cells under the first ledge, a step up off the floor.
        for x in [6, 10] {
            build.solid(x - 1, self.wide - 6, 0, x, self.wide - 1, a - 1);
            build.solid(x, self.wide - 6, 0, x + 3, self.wide - 1, 1);
            build.solid(x + 3, self.wide - 6, 0, x + 4, self.wide - 1, a - 1);
        }
        build.doorway(shaft, self.enter);
        for port in self.taken {
            build.doorway(shaft, port);
        }
        # Scrags wake as the player climbs to the first ledge; the second's
        # keeper as the player comes onto it.
        climb = build.touch(float(self.long - 4), float(self.wide - 6 - a), 0.0, float(self.long - 1), float(self.wide - 6), float(a + 6)) if self.stairs else build.touch(2.0, float(self.wide - 9), 0.0, 5.0, float(self.wide - 6), 6.0);
        air = build.waiting();
        climb +>:Fires:+> air;
        for index in range(dice.between(2, 3)) {
            build.foe(float(self.long // 2) - 1.5 + float(index), float(self.wide // 2) - 1.5 + float(index), 5 + index * 4, "monster_wizard", float(index * 120), waits=air);
        }
        onto = build.touch(float(self.long - 6), float(self.wide - 5), float(b), float(self.long - 4), float(self.wide - 2), float(b + 6));
        keeper = build.waiting();
        onto +>:Fires:+> keeper;
        build.foe(float(self.long) - 3.5, 4.5, b, E2M4_FOES.pick(dice, self.danger, True), 90.0, waits=keeper);
        build.foe(4.5, float(self.wide) - 3.0, a, E2M4_FOES.pick(dice, self.danger), 0.0, patrol=[[4.5, float(self.wide) - 3.0], [float(self.long) - 11.5, float(self.wide) - 3.0]]);
        build.foe(float(self.long // 2) - 1.5, 4.5, 0, E2M4_FOES.pick(dice, self.danger), 90.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 9.5, b, "item_health");
        build.supply(2.5, float(self.wide) - 3.5, a, "item_rockets");
        build.supply(2.5, 2.5, 0, "item_spikes");
    }
}

"""A hall of two galleries, a stair or a lift to each; a door on its floor
that will not open until a button is shot."""
node EbonHall(Prefab) {
    has lower: int = 6,
        upper: int = 15,
        stacked: bool = True,
        lift_low: bool = False,
        refuse: bool = True,
        sunk: bool = False,
        tall: int = 24;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ebon hall";
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.long = dice.between(28, 32);
        self.wide = dice.between(22, 26);
        self.lower = dice.between(6, 7);
        self.stacked = dice.chance(0.5);
        self.upper = self.lower + (9 if self.stacked else 7);
        self.lift_low = dice.chance(0.5);
        self.refuse = dice.chance(0.6);
        self.sunk = dice.chance(0.85);
        self.tall = self.upper + 13;
        self.low = -9;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=0, along=middle, floor=0),
            Port(face=1, along=12.0, floor=self.lower),
            Port(face=3, along=float(self.long // 2), floor=0),
            Port(face=0, along=float(self.wide - 3) if self.stacked else 5.0, floor=self.upper)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        low = self.lower;
        up = self.upper;
        middle = self.wide // 2;
        gy = self.wide - 7;
        hall = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(4));
        build.level(hall, low);
        build.level(hall, up);
        # The lower gallery along the north wall, over pillars.
        build.solid(1, gy, low - 1, self.long - 1, self.wide - 1, low);
        for x in range(12, self.long - 3, 5) {
            build.solid(x, gy, 0, x + 1, self.wide - 1, low - 1);
            if x + 5 < self.long - 3 {
                build.solid(x + 1, gy, 0, x + 5, self.wide - 1, 1);
            }
        }
        if self.lift_low {
            lift(build, 3, gy - 3, 6, gy, 0, low);
            for x in range(3, 6) {
                build.keep(hall, x, gy, low);
                build.keep(hall, x, gy - 4, 0);
            }
        } else {
            stair(build, 3, gy - 3, 0, 0, low, 3);
            for x in range(1 + low, 4 + low) {
                build.keep(hall, x, gy, low);
            }
        }
        if self.stacked {
            # The upper gallery right over the lower, a lift up from it.
            build.solid(10, self.wide - 5, up - 1, self.long - 1, self.wide - 1, up);
            lift(build, 6, self.wide - 5, 9, self.wide - 2, low, up);
            for y in range(self.wide - 5, self.wide - 2) {
                build.keep(hall, 10, y, up);
                build.keep(hall, 5, y, low);
            }
        } else {
            # The upper gallery along the east wall, a stair up to it along
            # the lower gallery.
            gx = self.long - 6;
            build.solid(gx, 1, up - 1, self.long - 1, self.wide - 1, up);
            stair(build, gx - 7, self.wide - 4, low, 0, 7, 3);
            for y in range(self.wide - 4, self.wide - 1) {
                build.keep(hall, gx, y, up);
            }
            for y in range(4, gy - 2, 5) {
                if abs(y - middle) > 3 {
                    build.solid(gx, y, 0, gx + 1, y + 1, up - 1);
                }
            }
        }
        # A pool sunk in the floor's middle.
        if self.sunk {
            px = self.long // 2 - 5;
            build.pool(px, middle - 4, -8, px + 10, middle + 4, 0, 2);
        }
        build.doorway(hall, self.enter);
        for port in self.taken {
            build.doorway(hall, port);
            # The door on the floor that will not open until the button high
            # on the south wall is shot (e2m4's "I don't think so...").
            if self.refuse and port.face == 0 and port.floor == 0 {
                fields = {"wait": "-1", "message": "I don't think so..."};
                build.rising_door(float(self.long - 1), port.along - 2.0, 0.0, float(self.long), port.along + 2.0, 8.0, fields);
                build.push(float(self.long - 8), 1.0, float(low) + 3.0, 1, True) +>:Fires:+> build.cue([fields], "door");
            }
        }
        # Scrags brought in as the player crosses the floor.
        crossing = build.touch(float(self.long // 2 - 7), 1.0, 0.0, float(self.long // 2 - 5), float(gy), 6.0);
        late = build.delay(1.0);
        crossing +>:Fires:+> late;
        for index in range(2) {
            late +>:Fires:+> build.summon(4 + index * 5, 3, -8, "monster_wizard", float(self.long // 2) + 0.5, float(middle) - 4.5 + float(index) * 9.0, 3, 0.0);
        }
        # Knights walk the floor; an ogre the lower gallery; what keeps the
        # upper gallery wakes as the player comes up to it.
        build.foe(12.5, 4.5, 0, "monster_knight", 0.0, patrol=[[12.5, 4.5], [float(self.long) - 4.5, 4.5]]);
        build.foe(float(self.long) - 6.5, float(middle) + 0.5, 0, E2M4_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(self.long) - 4.5, float(gy) + 1.5, low, "monster_ogre", 180.0, patrol=[[float(self.long) - 4.5, float(gy) + 1.5], [14.5, float(gy) + 1.5]]);
        coming = build.touch(float(self.long - 8), float(self.wide - 5), float(up), float(self.long - 1), float(self.wide - 1), float(up + 6)) if self.stacked else build.touch(float(self.long - 6), float(self.wide - 8), float(up), float(self.long - 1), float(self.wide - 1), float(up + 6));
        guard = build.waiting();
        coming +>:Fires:+> guard;
        for index in range(dice.between(1, 2)) {
            if self.stacked {
                build.foe(float(14 + index * 4) + 0.5, float(self.wide) - 3.0, up, E2M4_FOES.pick(dice, self.danger, True), 0.0, waits=guard);
            } else {
                build.foe(float(self.long) - 3.5, 4.5 + float(index) * 4.0, up, E2M4_FOES.pick(dice, self.danger, True), 90.0, waits=guard);
            }
        }
        build.supply(float(self.long) - 2.5, float(self.wide) - 3.0, up, "item_health");
        build.supply(2.5, 2.5, 0, "item_rockets");
        build.supply(float(self.long) - 2.5, float(gy) + 2.5, low, "item_shells");
    }
}

"""The key room: a pit of lava crossed to a ledge, the key caged on it
behind bars opened by a button elsewhere; taking it opens the closets."""
node SilverKeep(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        hops: int = 3,
        ledge: int = 8,
        cross: int = 0,
        up: int = 0,
        switch_at: int = 0,
        stash: bool = True,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Silver keep (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.hops = dice.between(3, 4);
        self.cross = dice.below(2);
        self.up = dice.below(2);
        self.switch_at = dice.below(2);
        self.stash = dice.chance(0.5);
        self.ledge = dice.between(8, 9);
        self.hall_wide = dice.between(15, 17);
        self.wide = self.hall_wide + 4;
        self.long = 3 * self.hops + 6 + 6 + 8;
        self.tall = self.ledge + dice.between(10, 12);
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
        k = self.ledge;
        far = 3 * self.hops + 6;
        kx = far + 6;
        hall = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(hall, k);
        build.doorway(hall, self.enter);
        # The pit of lava from x 5 to `far`: pillars to jump, or a bridge
        # drawn up out of the lava as the player walks up to its edge.
        build.pool(5, 1, -3, far, side, 0, 4, False, False);
        if self.cross == 0 {
            for hop in range(self.hops) {
                x = 6 + hop * 3;
                build.solid(x, cy - 1, -3, x + 2, cy + 2, 0);
            }
        } else {
            brink = build.touch(3.0, float(cy - 1), 0.0, 5.0, float(cy + 2), 6.0);
            brink +>:Fires:+> build.drawn(5.0, float(cy - 1), float(far), float(cy + 2), 0, 4);
            for y in range(cy - 1, cy + 2) {
                build.keep(hall, 4, y, 0);
                build.keep(hall, far, y, 0);
            }
        }
        # The ledge across the far end, a lift or a stair up to it, the cage
        # on it: a wall across with bars in its middle.
        build.solid(kx, 1, 0, self.long - 1, side, k);
        if self.up == 0 {
            lift(build, kx - 3, 2, kx, 5, 0, k);
            for y in range(2, 5) {
                build.keep(hall, kx, y, k);
                build.keep(hall, kx - 4, y, 0);
            }
        } else {
            stair(build, kx - 3, side - 1, 0, 3, k, 3);
            for y in range(side - k - 1, side - k + 2) {
                build.keep(hall, kx, y, k);
            }
        }
        cage = kx + 3;
        build.solid(cage, 1, k, cage + 1, cy - 2, k + 7);
        build.solid(cage, cy + 2, k, cage + 1, side, k + 7);
        build.solid(cage, 1, k + 7, cage + 1, side, k + 8);
        bars = e2m4_bars(build, float(cage), float(cy - 2), float(cage + 1), float(cy + 2), k, 7, "These bars open elsewhere...");
        if self.switch_at == 0 {
            build.push(float(kx), 2.5 if self.up == 1 else float(cy) + 0.5, 1.2, 2) +>:Fires:+> bars;
        } else {
            build.push(1.0, 2.5, 10.0, 0, True) +>:Fires:+> bars;
        }
        # The cage's keeper wakes as the bars go down.
        keeper = build.waiting();
        bars +>:Fires:+> keeper;
        build.foe(float(self.long) - 2.5, float(cy) + 3.5, k, E2M4_FOES.pick(dice, self.danger, True), 180.0, waits=keeper);
        # The key; taking it opens the closets along the side wall below.
        taken = e2m4_key(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, k);
        out = build.waiting();
        taken +>:Fires:+> out;
        for (index, at) in enumerate([1, far + 1]) {
            closet = build.room(at, side + 1, 0, at + 3, side + 4, 7);
            build.widen(closet, at, side, 0, at + 3, side + 1, 6);
            fields = {"wait": "-1"};
            build.rising_door(float(at), float(side), 0.0, float(at + 3), float(side + 1), 6.0, fields);
            taken +>:Fires:+> build.cue([fields], "door");
            build.foe(float(at) + 1.5, float(side) + 2.5, 0, E2M4_FOES.pick(dice, self.danger, index == 0), 270.0, waits=out);
        }
        if self.stash and self.up == 0 {
            e2m4_stash(build, kx + 2, side - 3, kx + 4, side - 1, 0, 2, "item_artifact_super_damage");
        }
        build.foe(float(far) + 2.5, 2.5, 0, E2M4_FOES.pick(dice, self.danger), 180.0);
        build.foe(float(far) - 3.5, float(cy) + 3.5, 6, "monster_wizard", 180.0);
        build.supply(2.5, 2.5, 0, "item_health");
        build.supply(float(kx) + 1.5, float(cy) + 0.5, k, "item_rockets");
    }
}

"""The end: a balcony over a hall, the way out behind bars the three
switches open."""
node SwitchVault(Prefab) {
    has key: str = "",
        top: int = 12,
        lifted: bool = True,
        lava: bool = False,
        spots: list[int] = [],
        tall: int = 26;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Switch vault" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = E2M4;
        self.district = level_district(E2M4);
        self.long = dice.between(28, 32);
        self.wide = dice.between(18, 20);
        self.top = dice.between(11, 13);
        self.lifted = dice.chance(0.5);
        self.lava = self.lifted and dice.chance(0.6);
        self.spots = dice.order(5)[:3];
        self.tall = self.top + dice.between(11, 13);
        self.low = -10;
        self.high = self.tall + 1;
        self.enter = Port(face=2, along=float(self.wide // 2), floor=self.top);
        self.leaves = [];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        t = self.top;
        middle = self.wide // 2;
        # The porch (a key's bars at its end, as a gate), the balcony across
        # the hall's near end, the hall below.
        porch = build.room(1, middle - 3, t, 4, middle + 3, t + 9, variant=dice.below(3));
        hall = build.room(5, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(hall, t);
        build.doorway(porch, self.enter);
        build.widen(hall, 4, middle - 2, t, 5, middle + 2, t + 8);
        if self.key {
            e2m4_bars(build, 4.0, float(middle - 2), 5.0, float(middle + 2), t, 8, "", self.key);
        }
        bx = 11;
        build.solid(5, 1, 0, bx, self.wide - 1, t);
        # Down: a lift at the balcony's edge, or a stair down the south wall.
        if self.lifted {
            lift(build, bx, middle - 1, bx + 3, middle + 2, 0, t);
            for y in range(middle - 1, middle + 2) {
                build.keep(hall, bx - 1, y, t);
                build.keep(hall, bx + 3, y, 0);
            }
        } else {
            stair(build, bx + t - 1, 1, 0, 2, t, 3);
            for y in range(1, 4) {
                build.keep(hall, bx - 1, y, t);
            }
        }
        # Chambers in the balcony's foot, a step up off the floor.
        build.room(6, 4, 1, bx, 8, 7);
        build.room(6, self.wide - 6, 1, bx, self.wide - 2, 7);
        build.supply(8.5, 6.0, 1, "item_health");
        # A channel of lava across the floor, bridged.
        if self.lava {
            cx = bx + 8;
            build.pool(cx, 1, -4, cx + 3, self.wide - 1, 0, 4, False, False);
            build.solid(cx, middle - 2, -1, cx + 3, middle + 2, 0);
            for y in range(middle - 2, middle + 2) {
                build.keep(hall, cx - 1, y, 0);
                build.keep(hall, cx + 3, y, 0);
            }
        }
        # The way out behind the bars in its alcove at the far end.
        ax = self.long - 7;
        build.solid(ax, 1, 0, self.long - 1, middle - 3, 12);
        build.solid(ax, middle + 3, 0, self.long - 1, self.wide - 1, 12);
        build.solid(ax, middle - 3, 9, self.long - 1, middle + 3, 12);
        bars = e2m4_bars(build, float(ax), float(middle - 3), float(ax + 1), float(middle + 3), 0, 9, "Shoot the switches...");
        build.way_out(float(self.long) - 3.5, float(middle), 0);
        # The three switches, high on the hall's walls; all shot, the bars
        # sink.
        count = build.tally(3, "The way out is open");
        count +>:Fires:+> bars;
        places = [
            [float(bx + 6), 1.0, float(t) - 2.0, 1.0],
            [float(bx + 12), float(self.wide - 1), float(t) - 2.0, 3.0],
            [float(ax), float(middle) + 5.0, 6.0, 2.0],
            [float(bx + 9), 1.0, 6.0, 1.0],
            [float(bx + 4), float(self.wide - 1), float(t) + 3.0, 3.0]
        ];
        for spot in self.spots {
            at = places[spot];
            build.push(at[0], at[1], at[2], int(at[3]), True) +>:Fires:+> count;
        }
        build.touch(float(bx - 3), float(middle - 3), float(t), float(bx), float(middle + 3), float(t + 6), True, "Shoot the switches...");
        # What waits on the floor wakes as the player comes down, and a
        # fiend is brought in before the bars.
        floor_touch = build.touch(float(bx), 1.0, 0.0, float(bx + 4), float(self.wide - 1), 6.0);
        below = build.waiting();
        floor_touch +>:Fires:+> below;
        for index in range(dice.between(2, 4)) {
            build.foe(float(ax) - 2.5 - float(index % 2) * 3.0, 3.5 + float(index) * 3.0, 0, E2M4_FOES.pick(dice, self.danger, index == 0), 180.0, waits=below);
        }
        late = build.delay(1.5);
        floor_touch +>:Fires:+> late;
        late +>:Fires:+> build.summon(bx + 3, 2, -8, E2M4_FOES.pick(dice, self.danger, True), float(ax) - 4.5, float(middle) + 0.5, 0, 180.0);
        build.foe(float(bx + 6) + 0.5, float(middle) + 0.5, t, "monster_wizard", 180.0);
        build.foe(float(bx) - 2.5, 2.5, t, E2M4_FOES.pick(dice, self.danger), 0.0);
        build.supply(2.5, float(middle) + 0.5, t, "item_health");
        build.supply(float(bx) + 4.5, float(self.wide) - 2.5, 0, "item_rockets");
    }
}

"""e2m4's stretches: [name, role]."""
glob E2M4_STRETCHES: list[list[str]] = [
         ["moat", "start"],
         ["crypt", "flow"],
         ["chasm", "flow"],
         ["shaft", "flow"],
         ["hall", "hub"],
         ["crypt", "hub"],
         ["hall", "flow"],
         ["keep", "keyroom"],
         ["vault", "end"],
         ["vault", "gate"]
     ];

"""One of e2m4's stretches by its name."""
def make_e2m4(name: str, key: str) -> Prefab {
    if name == "moat" {
        return MoatGate();
    }
    if name == "crypt" {
        return CryptUndercroft();
    }
    if name == "chasm" {
        return TrainChasm();
    }
    if name == "shaft" {
        return KeepShaft();
    }
    if name == "hall" {
        return EbonHall();
    }
    if name == "keep" {
        return SilverKeep(key=key if key else "key_silver");
    }
    return SwitchVault(key=key);
}
