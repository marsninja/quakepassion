"""Implementations for the world module: walker abilities and the graph
query/rewire helpers. Declarations live in world.jac."""

impl ThinkPass.start with World entry {
    visit [area for area in [here -->[?:Area]] if area.occupants > 0];
}

impl ThinkPass.at_area with Area entry {
    inside = [here <-:In:<-];
    # Entities removed without move_to_area leave a stale count; fix it.
    here.occupants = len(inside);
    visit inside;
}

impl ThinkPass.at_entity with Entity entry {
    self.entities_visited += 1;
}


impl VisPass.flood with Area entry {
    if here in self.seen {
        skip;
    }
    self.seen.append(here);
    self.visible.append(here);
    ports = [edge here ->:Portal:->];
    nbrs = [here ->:Portal:->];
    for i in range(len(ports)) {
        if portal_visible(self.eye, self.facing, ports[i].rect) {
            visit [nbrs[i]];
        }
    }
}


impl portal_visible(eye: Vec3, facing: Vec3, rect: AABB) -> bool {
    to_portal = rect.center().sub(eye);
    if to_portal.length() < 24.0 {
        return True;
    }
    return facing.dot(to_portal.normalized()) > -0.25;
}

impl area_containing(world: World, p: Vec3) -> Area | None {
    for a in [world -->[?:Area]] {
        if a.bounds.contains(p) {
            return a;
        }
    }
    return None;
}

impl area_of(ent: Entity) -> Area | None {
    areas = [ent ->:In:->[?:Area]];
    if areas {
        return areas[0];
    }
    return None;
}

impl move_to_area(ent: Entity, new_area: Area) {
    for old in [ent ->:In:->[?:Area]] {
        old.occupants = max(0, old.occupants - 1);
    }
    olds = [edge ent ->:In:->];
    for e in olds {
        del e;
    }
    ent +>: In :+> new_area;
    new_area.occupants += 1;
}
