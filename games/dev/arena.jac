"""The dev arena: two graybox rooms joined by a doorway, built by hand into
the world graph. This file is the contract for what phase 2's BSP loader
must produce — areas, portals, and a player, wired with connect operators."""

import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from engine.world.world { World, Area, Portal, In, Player, Surface }


def box(cx: float, cy: float, cz: float, sx: float, sy: float, sz: float, color: list[int]) -> Surface {
    return Surface(center=Vec3(x=cx, y=cy, z=cz), size=Vec3(x=sx, y=sy, z=sz), color=color);
}


"""Room A: x 0..256 | Room B: x 256..512 | both y 0..256, z 0..128.
Doorway in the shared wall: y 96..160, z 0..96. Each room owns its complete
shell (shared wall duplicated on both sides) so culling one room never
leaves holes in the other."""
def build_arena(world: World) -> Player {
    warm = [148, 138, 122];
    brown = [112, 86, 58];
    dark = [104, 96, 88];
    rust = [126, 60, 38];
    ember = [198, 100, 34];

    a = Area(
        name="ante",
        bounds=AABB(mins=Vec3(x=0.0, y=0.0, z=0.0), maxs=Vec3(x=256.0, y=256.0, z=128.0)),
        surfaces=[
            box(128, 128, -4, 272, 272, 8, brown),       # floor
            box(128, 128, 132, 272, 272, 8, warm),       # ceiling
            box(-4, 128, 64, 8, 272, 128, warm),         # west wall
            box(128, -4, 64, 272, 8, 128, warm),         # south wall
            box(128, 260, 64, 272, 8, 128, warm),        # north wall
            box(254, 48, 64, 8, 96, 128, warm),          # east wall, south of door
            box(254, 208, 64, 8, 96, 128, warm),         # east wall, north of door
            box(254, 128, 112, 8, 64, 32, warm),         # lintel over door
            box(180, 200, 16, 32, 32, 32, ember)         # a crate to fly around
        ]
    );

    b = Area(
        name="hall",
        bounds=AABB(mins=Vec3(x=256.0, y=0.0, z=0.0), maxs=Vec3(x=512.0, y=256.0, z=128.0)),
        surfaces=[
            box(384, 128, -4, 272, 272, 8, rust),        # floor
            box(384, 128, 132, 272, 272, 8, dark),       # ceiling
            box(516, 128, 64, 8, 272, 128, dark),        # east wall
            box(384, -4, 64, 272, 8, 128, dark),         # south wall
            box(384, 260, 64, 272, 8, 128, dark),        # north wall
            box(258, 48, 64, 8, 96, 128, dark),          # west wall, south of door
            box(258, 208, 64, 8, 96, 128, dark),         # west wall, north of door
            box(258, 128, 112, 8, 64, 32, dark),         # lintel over door
            box(400, 80, 64, 24, 24, 128, ember),        # pillar
            box(440, 192, 64, 24, 24, 128, ember)        # pillar
        ]
    );

    world ++> a;
    world ++> b;
    a <+: Portal(
        rect=AABB(mins=Vec3(x=250.0, y=96.0, z=0.0), maxs=Vec3(x=262.0, y=160.0, z=96.0))
    ) :+> b;

    player = Player(pos=Vec3(x=64.0, y=128.0, z=56.0), yaw=0.0, pitch=0.0);
    player +>: In :+> a;
    return player;
}
