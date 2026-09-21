"""Shared activation graph. Relays forward; consumers drain queued requests."""
import from .world { World }
import from .inventory { Inventory, quantity, AdjustInventory }

edge Targets: Signal --> Signal {}
edge HasSignal: World --> Signal {}

node Signal {
    has entities: list[int] = [],
        enabled: bool = True,
        name: str = "",
        target: str = "",
        relay: bool = False,
        pending: int = 0,
        key: str = "",
        remaining: int = 0,
        once: bool = False;
}

walker Fire {
    has emit: bool = True,
        inventory: Inventory | None = None,
        message: str = "",
        seen: list[Signal] = [];

    can deliver with Signal entry {
        if not here.enabled or here in self.seen { return; }
        self.seen.append(here);
        if self.emit {
            self.emit = False;
            visit [here->:Targets:->];
        } elif here.relay {
            if here.key {
                if self.inventory is None or quantity(self.inventory, here.key) <= 0 {
                    self.message = "Need " + here.key.replace("key_", "").replace("_", " ");
                    return;
                }
                self.inventory spawn AdjustInventory(kind=here.key, amount=-1);
            }
            if here.remaining > 0 {
                here.remaining -= 1;
                if here.remaining > 0 {
                    self.message = "Objective: " + str(here.remaining) + " more activations";
                    return;
                }
                self.message = "Objective complete";
            }
            if here.once { here.enabled = False; }
            visit [here->:Targets:->];
        } else {
            here.pending += 1;
        }
    }
}
