"""Shared activation graph. Relays forward; consumers drain queued requests."""
import from .world { World }
import from .inventory { Inventory, quantity, AdjustInventory }

edge Targets: Signal --> Signal {}
edge HasSignal: World --> Signal {}
edge HasProgress: World --> Progress {}
node Progress {
    has secrets: int = 0,
        total_secrets: int = 0,
        goals: int = 0,
        total_goals: int = 0;
}

def progress_for(world: World) -> Progress {
    records = [world->:HasProgress:->][?:Progress];
    if records {
        return records[0];
    }
    record = Progress();
    world +>:HasProgress:+> record;
    return record;
}

def progress_summary(world: World) -> str {
    parts: list[str] = [];
    for progress in [world->:HasProgress:->][?:Progress] {
        if progress.total_secrets > 0 {
            parts.append(
                "Secrets: " + str(progress.secrets) + "/" + str(progress.total_secrets)
            );
        }
        if progress.total_goals > 0 {
            parts.append(
                "Goals: " + str(progress.goals) + "/" + str(progress.total_goals)
            );
        }
    }
    return " | ".join(parts);
}

obj DelayedUse {
    has remaining: float,
        inventory: Inventory | None = None;
}

obj ReadyUse {
    has source: Signal,
        inventory: Inventory | None = None,
        scheduled: bool = True;
}

node Signal {
    has entities: list[int] = [],
        enabled: bool = True,
        name: str = "",
        target: str = "",
        relay: bool = False,
        pending: int = 0,
        key: str = "",
        remaining: int = 0,
        once: bool = False,
        objective: str = "",
        progress: Progress | None = None,
        delay: float = 0.0,
        variance: float = 0.0,
        replace_pending: bool = False,
        random_state: int = 1,
        queued: list[DelayedUse] = [],
        interval: float = 0.0,
        timer_running: bool = False,
        timer_remaining: float = 0.0,
        timer_inventory: Inventory | None = None;

    def sample(base: float) -> float {
        duration = base;
        if self.variance > 0.0 {
            self.random_state = (self.random_state * 48271) % 2147483647;
            duration += self.variance
                * (2.0 * float(self.random_state) / 2147483647.0 - 1.0);
        }
        return max(0.0, duration);
    }

    def schedule(inventory: Inventory | None) {
        if self.replace_pending {
            self.queued = [];
        }
        # Timer variance belongs to its interval, not its output delay.
        duration = self.sample(self.delay) if self.interval == 0.0 else self.delay;
        self.queued.append(DelayedUse(remaining=duration, inventory=inventory));
    }
}

walker Fire {
    has emit: bool = True,
        scheduled: bool = False,
        inventory: Inventory | None = None,
        message: str = "",
        seen: list[Signal] = [];

    can deliver with Signal entry {
        if (not here.enabled and not (self.emit and self.scheduled))
            or here in self.seen {
            return;
        }
        self.seen.append(here);
        if self.emit {
            self.emit = False;
            if here.delay > 0.0 and not self.scheduled {
                here.schedule(self.inventory);
                return;
            }
            self.scheduled = False;
            visit [here->:Targets:->];
        } elif here.interval > 0.0 {
            here.timer_inventory = self.inventory;
            here.timer_running = not here.timer_running;
            if not here.timer_running {
                return;
            }
            if here.delay > 0.0 {
                here.timer_remaining = here.delay;
                return;
            }
            here.timer_remaining = here.sample(here.interval);
            visit [here->:Targets:->];
        } elif here.relay {
            if here.key {
                if self.inventory is None or quantity(self.inventory, here.key) <= 0 {
                    self.message = "Need "
                        + here.key.replace("key_", "").replace("_", " ");
                    return;
                }
                self.inventory spawn AdjustInventory(kind=here.key, amount=-1);
            }
            if here.remaining > 0 {
                here.remaining -= 1;
                if here.remaining > 0 {
                    self.message = "Objective: "
                        + str(here.remaining)
                        + " more activations";
                    return;
                }
                self.message = "Objective complete";
            }
            record = here.progress;
            if record is not None {
                if here.objective == "secret" {
                    record.secrets += 1;
                    self.message = "Secret found! "
                        + str(record.secrets)
                        + "/"
                        + str(record.total_secrets);
                } elif here.objective == "goal" {
                    record.goals += 1;
                    self.message = "Objective complete: "
                        + str(record.goals)
                        + "/"
                        + str(record.total_goals);
                }
            }
            if here.once {
                here.enabled = False;
            }
            if here.delay > 0.0 {
                here.schedule(self.inventory);
                return;
            }
            visit [here->:Targets:->];
        } else {
            here.pending += 1;
        }
    }
}


# Collect first, deliver second: newly scheduled events never age in this tick.
walker SignalTick {
    has dt: float,
        ready: list[ReadyUse] = [],
        message: str = "";

    can start with World entry {
        if self.dt > 0.0 {
            visit [
                signal
                for signal in [here->:HasSignal:->][?:Signal]
                if signal.queued or signal.timer_running
            ];
        }
    }

    can advance with Signal entry {
        pending: list[DelayedUse] = [];
        for event in here.queued {
            event.remaining = max(0.0, event.remaining - self.dt);
            if event.remaining <= 0.0 {
                self.ready.append(ReadyUse(source=here, inventory=event.inventory));
            } else {
                pending.append(event);
            }
        }
        here.queued = pending;
        if here.enabled and here.timer_running {
            here.timer_remaining = max(0.0, here.timer_remaining - self.dt);
            if here.timer_remaining <= 0.0 {
                here.timer_remaining = here.sample(here.interval);
                self.ready.append(
                    ReadyUse(
                        source=here, inventory=here.timer_inventory, scheduled=False
                    )
                );
            }
        }
    }

    can finish with World exit {
        for event in self.ready {
            fired = event.source spawn Fire(
                scheduled=event.scheduled, inventory=event.inventory
            );
            if fired.message {
                self.message = fired.message;
            }
        }
    }
}
