"""Shared activation graph. Relays forward; consumers drain queued requests."""
import from .world { World }

edge Targets: Signal --> Signal {}
edge HasSignal: World --> Signal {}

node Signal {
    has entities: list[int] = [],
        enabled: bool = True,
        name: str = "",
        target: str = "",
        relay: bool = False,
        pending: int = 0;
}

walker Fire {
    has emit: bool = True,
        seen: list[Signal] = [];

    can deliver with Signal entry {
        if not here.enabled or here in self.seen { return; }
        self.seen.append(here);
        if self.emit {
            self.emit = False;
            visit [here->:Targets:->];
        } elif here.relay {
            visit [here->:Targets:->];
        } else {
            here.pending += 1;
        }
    }
}
