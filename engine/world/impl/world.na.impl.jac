"""Implementations for the world module: walker abilities and the graph
query/rewire helpers. Declarations live in world.na.jac."""

impl ThinkPass.start with World entry {
    visit [here -->[?:Area]];
}

impl ThinkPass.at_area with Area entry {
    visit [here <-:In:<-];
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
    olds = [edge ent ->:In:->];
    for e in olds {
        del e;
    }
    ent +>: In :+> new_area;
}
