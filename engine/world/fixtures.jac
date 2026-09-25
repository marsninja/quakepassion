"""Decorative map models (torches, flames, lamps, bodies, banners) as graph
entities that animate on the world clock without any game logic."""
import from .world { World, Entity }
import from .models { Visual }
import from .signals { Signal, HasSignal }
import from ..formats.bsp { Bsp }

edge HasFixture: World --> Fixture {}
node Fixture(Entity) {
    has visual: Visual = Visual(),
        frames: list[int] = [],
        rate: float = 10.0,
        clock: float = 0.0,
        once: bool = False,
        activation: Signal | None = None,
        usage: str = "";
}

"""Q2 fixtures with a use: misc_blackhole_use frees the black hole and
misc_satellite_dish_use plays the dish's 38 frames once. Their signals exist
before chains are resolved; populate_fixtures attaches them to the models."""
glob FIXTURE_USES: dict[str, str] = {
    "misc_blackhole": "remove",
    "misc_satellite_dish": "sweep"
};

def load_fixture_uses(world: World, bsp: Bsp) {
    if bsp.game != "q2" {
        return;
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") in FIXTURE_USES and fields.get("targetname", "") {
            world +>:HasSignal:+> Signal(entities=[index]);
        }
    }
}

def fixture_signal(world: World, index: int) -> Signal | None {
    for signal in [world->:HasSignal:->][?:Signal] {
        if signal.entities == [index] {
            return signal;
        }
    }
    return None;
}

walker FixtureTick {
    has dt: float;

    can begin with World entry {
        if self.dt > 0.0 {
            visit [here->:HasFixture:->];
        }
    }

    can animate with Fixture entry {
        signal = here.activation;
        if signal is not None and (signal.pending > 0 or signal.killed) {
            signal.pending = 0;
            if here.usage == "remove" or signal.killed {
                here.visual.visible = False;
                here.frames = [];
            } elif here.usage == "sweep" {
                here.frames = list(range(38));
                here.once = True;
                here.clock = 0.0;
            }
        }
        if len(here.frames) < 2 {
            return;
        }
        here.clock += self.dt * here.rate;
        count = len(here.frames);
        if here.once and int(here.clock) >= count - 1 {
            here.clock = float(count - 1);
        }
        index = int(here.clock) % count;
        here.visual.first = here.frames[index];
        here.visual.second = here.frames[(index + 1) % count];
        here.visual.blend = here.clock - float(int(here.clock));
    }
}
