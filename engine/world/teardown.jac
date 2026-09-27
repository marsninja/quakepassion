"""Level teardown. A live edge keeps both of its nodes alive, so a level's
graph outlives the level unless it is destroyed: loading the next level
tears the last one down."""
import from ..physics.collision { CollisionMap }

"""Gathers every node reachable from where it starts, and from its extra
roots, over edges in either direction."""
walker Teardown {
    has roots: list[Node] = [],
        seen: set[Node] = set(),
        doomed: list[Node] = [];

    can gather with Node entry {
        if here in self.seen {
            return;
        }
        if not self.seen {
            visit self.roots;
        }
        self.seen.add(here);
        self.doomed.append(here);
        visit [-->];
        visit [<--];
    }
}

"""Destroy `start`'s graph and everything connected to `roots`; the number
of nodes destroyed."""
def destroy_graph(start: Node, roots: list[Node]) -> int {
    sweep = start spawn Teardown(roots=roots);
    for doomed in sweep.doomed {
        del doomed;
    }
    return len(sweep.doomed);
}

"""The node graphs a collision map owns: its hull trees and bounds tree."""
def collision_roots(collision: CollisionMap) -> list[Node] {
    roots: list[Node] = [];
    for cell in collision.hulls {
        roots.append(cell);
    }
    for cell in collision.point_hulls {
        roots.append(cell);
    }
    for group in collision.groups {
        roots.append(group);
    }
    return roots;
}
