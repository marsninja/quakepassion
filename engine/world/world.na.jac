"""The world is a graph. Areas joined by Portals, Entities living In areas,
and engine systems as walkers that travel it. Read this file top to bottom
and you understand how the engine thinks.

Nothing here knows raylib exists. Rendering hands happen in engine/render;
this module owns structure and traversal only. Walker abilities and the graph
helpers are bodied in impl/world.na.impl.jac; this file is the declaration
surface."""

import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }


"""A single axis-aligned box of world geometry (phase 1 graybox)."""
obj Surface {
    has center: Vec3,
        size: Vec3,
        color: list[int] = [200, 200, 200];
}


node World {
    has name: str = "dev";
}


"""A region of the map. Phase 2 builds these from BSP leafs/clusters;
phase 1 builds them by hand."""
node Area {
    has name: str,
        bounds: AABB,
        surfaces: list[Surface] = [];
}


"""Connects two Areas through an opening. Visibility floods through these."""
edge Portal {
    has rect: AABB;
}


"""An Entity lives In exactly one Area. The edge is rewired as it moves."""
edge In {}


node Entity {
    has pos: Vec3 = Vec3(),
        yaw: float = 0.0,
        pitch: float = 0.0;
}


node Player(Entity) {}


"""Per-tick entity logic. Phase 1 is a deliberate stub that still runs every
tick so the dispatch pattern is locked in: entity subtypes (Door, Monster...)
will answer with their own `can think with ThinkPass entry` abilities —
Quake's think-function-pointers reborn as ability dispatch."""
walker ThinkPass {
    has dt: float = 0.05,
        entities_visited: int = 0;

    can start with World entry;
    can at_area with Area entry;
    can at_entity with Entity entry;
}


"""Visibility as graph traversal: flood outward from the camera's Area,
crossing only portals the eye could plausibly see through. The walker
carries its own seen-list — revisiting is opt-in in jac, and portals
are bidirectional, so the guard is what terminates the flood."""
walker VisPass {
    has eye: Vec3 = Vec3(),
        facing: Vec3 = Vec3(x=1.0),
        visible: list[Area] = [],
        seen: list[Area] = [];

    can flood with Area entry;
}


# RenderPass — the third engine pass — lives in engine/render/renderer.jac,
# not here. It must hold a concrete `renderer: Renderer`, and typing it here
# would create a world->renderer import cycle. Keeping it in the render layer
# leaves this module raylib-free and every field in it strongly typed.


"""Can the eye see through this portal opening? Phase 1 keeps it honest and
simple: the portal is visible when it sits in front of the camera's facing
hemisphere (with a little slack), or the eye is practically inside it.
Phase 2 graduates to real portal-frustum clipping."""
def portal_visible(eye: Vec3, facing: Vec3, rect: AABB) -> bool;


"""Which area contains this point? The spatial query behind In-edge rewiring."""
def area_containing(world: World, p: Vec3) -> Area | None;


"""Current area of an entity via its In edge."""
def area_of(ent: Entity) -> Area | None;


"""Rewire an entity's In edge when it crosses into a new area."""
def move_to_area(ent: Entity, new_area: Area);
