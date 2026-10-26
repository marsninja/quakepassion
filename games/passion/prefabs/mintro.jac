"""Prefabs drawn from Quake II's mintro, the Mine Entrance: a rocky yard
under the sky with a stream of lava across it, a tunnel the carts ran
down, an ore works over a pit of lava with hoppers and walkways, the key
in the foreman's shack up on a ledge. Raised in mintro's own palette.

- `MineYard`: the start. A yard of rock under the sky, a stream of lava
  across it bridged, the mine's mouth beyond; ways on from the mouth and
  the yard.
- `CartTunnel`: a tunnel sloping down a lift every few cells, rails along
  its walls, the way on at its foot.
- `OreWorks`: a works over a pit of lava, walkways across it between
  hoppers, a gallery up a stair; ways on from the floor and the gallery
  (a hub).
- `ForemanShack`: the key in a shack on a ledge up a stair; taking it opens
  the closets below.
- `MintroExit`: the end. A door (a key's, as a gate), a lift cage's floor,
  the way out in it."""
import from ..random { Stream }
import from ..prefab { Prefab, Port, Lay, Raise, Raising }
import from ..kits { level_district }
import from .roster { q1_foe, q1_palette, Q2_HEALTH, Q2_AMMO, Q2_ARMOR }
import from .common { stair, boulders, key_ambush, gate_into }

glob MINTRO: str = "q2:mintro";

"""mintro's foes: soldiers and berserkers, flyers and hovers, a mutant
deeper in."""
def mintro_foe(dice: Stream, danger: float, heavy: bool = False, flying: bool = False) -> str {
    if flying {
        return "monster_hover" if dice.chance(0.3) else "monster_flyer";
    }
    return q1_foe(dice, q1_palette(["monster_berserk", "monster_soldier_ss"] if heavy else ["monster_soldier_light", "monster_soldier_light", "monster_berserk"], ["monster_mutant"] if heavy else ["monster_berserk"], danger * 0.6 if heavy else danger));
}

"""The start: a yard of rock, a stream of lava across it bridged."""
node MineYard(Prefab) {
    has tall: int = 22;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Mine yard";
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.long = dice.between(28, 30);
        self.wide = dice.between(20, 22);
        self.tall = dice.between(20, 24);
        self.low = -4;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=0), Port(face=1, along=float(self.long - 9), floor=0), Port(face=3, along=float(self.long - 9), floor=0)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        yard = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3), sky=True);
        sx = 11;
        build.pool(sx, 1, -3, sx + 4, self.wide - 1, 0, 4, False, False);
        build.solid(sx, middle - 2, -3, sx + 4, middle + 2, 0);
        for y in range(middle - 2, middle + 2) {
            build.keep(yard, sx - 1, y, 0);
            build.keep(yard, sx + 4, y, 0);
        }
        # The mine's mouth: a block of rock over the far end, a portal in it.
        mx = self.long - 6;
        build.solid(mx, 1, 0, self.long - 1, self.wide - 1, 12);
        build.widen(yard, mx, middle - 2, 0, self.long - 1, middle + 2, 8);
        clear = [[0, middle - 3, 5, middle + 3], [sx - 2, 0, sx + 6, self.wide], [mx - 3, middle - 3, mx, middle + 3], [self.long - 8, 0, self.long, 4], [self.long - 8, self.wide - 4, self.long, self.wide]];
        boulders(build, dice, 1, 1, mx, self.wide - 1, 0, dice.between(5, 8), clear);
        build.doorway(yard, self.enter);
        for port in self.taken {
            build.doorway(yard, port);
        }
        build.start(2.5, float(middle) + 0.5, 0, 0.0);
        build.supply(2.5, float(middle) - 1.5, 0, "ammo_shells", "q2");
        for index in range(dice.between(3, 4)) {
            build.foe(float(sx + 6 + index % 2 * 3) + 0.5, 3.5 + float(index) * 4.0, 0, mintro_foe(dice, self.danger), 180.0);
        }
        build.foe(float(self.long // 2) + 0.5, float(middle) + 4.5, 8, mintro_foe(dice, self.danger, False, True), 180.0);
        build.supply(float(mx) - 2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""A tunnel sloping down a lift every few cells, rails along its walls."""
node CartTunnel(Prefab) {
    has drop: int = 8,
        tall: int = 10;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Cart tunnel";
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.long = dice.between(28, 32);
        self.wide = dice.between(10, 12);
        self.drop = dice.between(7, 9);
        self.tall = dice.between(9, 11);
        self.low = -self.drop - 2;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [Port(face=0, along=middle, floor=-self.drop), Port(face=1, along=float(self.long - 4), floor=-self.drop)];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        middle = self.wide // 2;
        low = -self.drop;
        tunnel = build.room(1, 1, low, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(tunnel, 0);
        # The slope: a lift down every few cells, a landing at the head and
        # the foot, the rails a lift high along both walls.
        head = 5;
        run = self.long - 10;
        for x in range(1, self.long - 1) {
            if x < head {
                top = 0;
            } elif x < head + run {
                top = -((x - head) * self.drop) // run;
            } else {
                top = low;
            }
            build.solid(x, 1, low - 1, x + 1, self.wide - 1, top);
        }
        for x in range(head, head + run) {
            floor_at = -((x - head) * self.drop) // run;
            build.solid(x, 1, floor_at, x + 1, 2, floor_at + 1);
            build.solid(x, self.wide - 2, floor_at, x + 1, self.wide - 1, floor_at + 1);
        }
        build.doorway(tunnel, self.enter);
        for port in self.taken {
            build.doorway(tunnel, port);
        }
        for index in range(dice.between(2, 3)) {
            build.foe(float(head + 6 + index * 6) + 0.5, float(middle) + 1.5, -((6 + index * 6) * self.drop) // run, mintro_foe(dice, self.danger, index == 0), 180.0);
        }
        build.supply(float(self.long) - 3.0, float(middle) + 0.5, low, Q2_HEALTH, "q2");
        build.supply(2.5, 2.5, 0, "ammo_bullets", "q2");
    }
}

"""A works over a pit of lava, walkways across it between hoppers, a
gallery up a stair."""
node OreWorks(Prefab) {
    has gallery: int = 7,
        tall: int = 20;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Ore works";
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.long = dice.between(28, 30);
        self.wide = dice.between(24, 26);
        self.gallery = dice.between(7, 8);
        self.tall = self.gallery + 12;
        self.low = -5;
        self.high = self.tall + 1;
        middle = float(self.wide // 2);
        self.enter = Port(face=2, along=middle, floor=0);
        self.leaves = [
            Port(face=1, along=float(self.long // 2), floor=self.gallery),
            Port(face=0, along=middle, floor=0),
            Port(face=3, along=float(self.long // 2) + 4.0, floor=0),
            Port(face=0, along=float(self.wide - 3), floor=self.gallery)
        ];
        visitor.place(self);
    }

    can rise with Raise entry {
        build = visitor.build;
        dice = build.begin(self);
        cx = self.long // 2;
        cy = self.wide // 2;
        works = build.room(1, 1, 0, self.long - 1, self.wide - 1, self.tall, variant=dice.below(3));
        build.level(works, self.gallery);
        build.pool(6, 6, -4, self.long - 6, self.wide - 6, 0, 4, False, False);
        build.solid(6, cy - 2, -4, self.long - 6, cy + 2, 0);
        build.solid(cx - 2, 6, -4, cx + 2, self.wide - 6, 0);
        # Hoppers: blocks standing in the lava, funnels over the walkways.
        for corner in [[9, 9], [self.long - 12, 9], [9, self.wide - 12], [self.long - 12, self.wide - 12]] {
            build.solid(corner[0], corner[1], -4, corner[0] + 3, corner[1] + 3, 6);
        }
        under = self.gallery - 1;
        build.solid(1, self.wide - 4, under, self.long - 1, self.wide - 1, self.gallery);
        stair(build, 1, self.wide - 4 - self.gallery, 0, 1, self.gallery, 3);
        for x in range(1, 4) {
            build.keep(works, x, self.wide - 4, self.gallery);
        }
        build.doorway(works, self.enter);
        for port in self.taken {
            build.doorway(works, port);
        }
        for index in range(dice.between(3, 4)) {
            build.foe(3.5 if index % 2 == 0 else float(self.long) - 3.5, 4.5 + float(index) * 4.0, 0, mintro_foe(dice, self.danger), 0.0);
        }
        build.foe(float(cx) + 0.5, float(cy) + 0.5, 0, mintro_foe(dice, self.danger, True), 180.0);
        build.foe(float(cx) + 0.5, float(self.wide) - 2.5, self.gallery, mintro_foe(dice, self.danger), 270.0);
        build.supply(float(self.long) - 2.5, float(self.wide) - 2.5, self.gallery, Q2_ARMOR, "q2");
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The key in a shack on a ledge up a stair; taking it opens the closets
below."""
node ForemanShack(Prefab) {
    has key: str = "key_silver",
        hall_wide: int = 16,
        ledge: int = 5,
        tall: int = 14;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Foreman shack (" + ("gold" if self.key == "key_gold" else "silver") + ")";
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.long = dice.between(20, 22);
        self.hall_wide = dice.between(16, 18);
        self.wide = self.hall_wide + 4;
        self.ledge = dice.between(5, 6);
        self.tall = self.ledge + 9;
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
        cave = build.room(1, 1, 0, self.long - 1, side, self.tall, variant=dice.below(3));
        build.level(cave, self.ledge);
        build.doorway(cave, self.enter);
        lx = self.long - 7;
        build.solid(lx, 1, 0, self.long - 1, side, self.ledge);
        stair(build, lx - self.ledge, 2, 0, 0, self.ledge, 3);
        # The shack: walls round the ledge's far half, a doorway in front.
        build.solid(lx + 2, cy - 4, self.ledge, lx + 3, cy - 1, self.ledge + 5);
        build.solid(lx + 2, cy + 2, self.ledge, lx + 3, cy + 5, self.ledge + 5);
        build.solid(lx + 2, cy - 4, self.ledge + 5, self.long - 1, cy + 5, self.ledge + 6);
        key_ambush(build, self.key, float(self.long) - 3.0, float(cy) + 0.5, self.ledge, side, 0, [2, lx - 4], [mintro_foe(dice, self.danger, True), mintro_foe(dice, self.danger)]);
        build.foe(float(lx) + 1.0, 3.0, self.ledge, mintro_foe(dice, self.danger), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""The end: a door, a lift cage's floor, the way out in it."""
node MintroExit(Prefab) {
    has key: str = "",
        tall: int = 16;

    can choose with Lay entry {
        dice = visitor.dice_for(self);
        self.title = "Mine lift" + (" (" + self.key[4:] + " door)" if self.key else "");
        self.source = MINTRO;
        self.district = level_district(MINTRO);
        self.long = dice.between(22, 24);
        self.wide = dice.between(14, 16);
        self.tall = dice.between(15, 17);
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
        gate_into(build, dice, self.enter, self.long, self.wide, wall, 0, self.tall, self.key);
        cage_x = self.long - 7;
        for y in [middle - 4, middle + 3] {
            build.solid(cage_x, y, 0, self.long - 1, y + 1, self.tall);
        }
        build.solid(cage_x, middle - 4, 0, self.long - 1, middle + 4, 1);
        build.way_out(float(self.long) - 3.5, float(middle), 1);
        for index in range(dice.between(2, 3)) {
            build.foe(float(wall) - 3.5, 2.5 + float(index) * 4.0, 0, mintro_foe(dice, self.danger, index == 0), 180.0);
        }
        build.foe(float(cage_x) - 3.5, 2.5, 0, mintro_foe(dice, self.danger, True), 180.0);
        build.supply(2.5, 2.5, 0, Q2_HEALTH, "q2");
    }
}

"""mintro's stretches: [name, role]."""
glob MINTRO_STRETCHES: list[list[str]] = [
         ["yard", "start"],
         ["tunnel", "flow"],
         ["works", "hub"],
         ["works", "flow"],
         ["shack", "keyroom"],
         ["exit", "end"],
         ["exit", "gate"]
     ];

"""One of mintro's stretches by its name."""
def make_mintro(name: str, key: str) -> Prefab {
    if name == "yard" {
        return MineYard();
    }
    if name == "tunnel" {
        return CartTunnel();
    }
    if name == "works" {
        return OreWorks();
    }
    if name == "shack" {
        return ForemanShack(key=key if key else "key_silver");
    }
    return MintroExit(key=key);
}
