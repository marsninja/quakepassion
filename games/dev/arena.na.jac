"""The dev arena: two graybox rooms joined by a doorway, built by hand into
the world graph. This file is the contract for what phase 2's BSP loader
must produce — areas, portals, and a player, wired with connect operators.

Function bodies live in impl/arena.na.impl.jac."""

import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from engine.world.world { World, Area, Portal, In, Player, Surface }


def box(cx: float, cy: float, cz: float, sx: float, sy: float, sz: float, color: list[int]) -> Surface;


"""Room A: x 0..256 | Room B: x 256..512 | both y 0..256, z 0..128.
Doorway in the shared wall: y 96..160, z 0..96. Each room owns its complete
shell (shared wall duplicated on both sides) so culling one room never
leaves holes in the other."""
def build_arena(world: World) -> Player;
