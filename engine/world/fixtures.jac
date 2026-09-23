"""Decorative map models (torches, flames, lamps, bodies, banners) as graph
entities that animate on the world clock without any game logic."""
import from .world { World, Entity }
import from .models { Visual }

edge HasFixture: World --> Fixture {}
node Fixture(Entity) {
    has visual: Visual = Visual(),
        frames: list[int] = [],
        rate: float = 10.0,
        clock: float = 0.0;
}

walker FixtureTick {
    has dt: float;

    can begin with World entry {
        if self.dt > 0.0 {
            visit [here->:HasFixture:->];
        }
    }

    can animate with Fixture entry {
        if len(here.frames) < 2 {
            return;
        }
        here.clock += self.dt * here.rate;
        count = len(here.frames);
        index = int(here.clock) % count;
        here.visual.first = here.frames[index];
        here.visual.second = here.frames[(index + 1) % count];
        here.visual.blend = here.clock - float(int(here.clock));
    }
}
