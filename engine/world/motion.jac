"""The tick boundary of render interpolation (engine/math/interpolation.jac):
before each physics tick, every body that moves remembers where it stands,
so frames drawn during the tick can place it between there and where the
tick leaves it."""
import from .world { World, Area, Entity, In }
import from .combat { Projectile, HasProjectile }

"""Walks the world's bodies as a physics tick begins: every entity in an
occupied area (actors, items, gibs, corpses; the ones GatherModels draws)
and every projectile in flight, capturing its pose for tick `tick`. `areas`
spares a walk over every leaf's edges, as for GatherModels."""
walker CaptureMotion {
    has tick: int = 0,
        areas: list[Area] = [];

    can begin with World entry {
        places = self.areas if self.areas else [here-->[?:Area]];
        visit [area for area in places if area.occupants > 0];
        visit [here->:HasProjectile:->];
    }

    can area with Area entry {
        visit [here<-:In:<-];
    }

    can entity with Entity entry {
        here.tick_pose.capture(here.pos, here.yaw, here.pitch, self.tick);
    }

    can projectile with Projectile entry {
        here.tick_pose.capture(here.pos, 0.0, 0.0, self.tick);
    }
}
