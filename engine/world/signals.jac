"""Shared activation graph. Relays forward; consumers drain queued requests."""
import from .world { World }
import from .inventory { Inventory, quantity, AdjustInventory }

edge Targets: Signal --> Signal {}
"""killtarget: firing the source removes each killed recipient (SUB_UseTargets)."""
edge Kills: Signal --> Signal {}
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

"""Load-time diagnostics: an entity a chain skips or a mover left static, and
why. scripts/chain_audit.jac reports them per map."""
edge HasChainNote: World --> ChainNote {}
node ChainNote {
    has entity: int,
        reason: str;
}

def note_chain(world: World, entity: int, reason: str) {
    world +>:HasChainNote:+> ChainNote(entity=entity, reason=reason);
}

def chain_notes(world: World) -> list[ChainNote] {
    return [world->:HasChainNote:->][?:ChainNote];
}

"""trigger_counter progress: Q1 counter_use and Q2 trigger_counter_use."""
def counter_text(style: str, remaining: int) -> str {
    if style == "silent" {
        return "";
    }
    if style == "q1" {
        return "There are more to go..." if remaining >= 4 else "Only " + str(remaining) + " more to go...";
    }
    return str(remaining) + " more to go...";
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
        timer_inventory: Inventory | None = None,
        message: str = "",
        cue: str = "",
        killed: bool = False,
        armable: bool = False,
        armed: bool = True,
        counter_style: str = "",
        grant_flags: int = 0,
        require_flags: int = 0,
        pathtarget: str = "",
        routed: bool = False,
        calls: list[str] = [];

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
        cues: list[str] = [],
        seen: list[Signal] = [];

    # SUB_UseTargets/G_UseTargets: show the message, remove killtargets, then
    # the caller visits the targets.
    def announce(source: Signal) {
        if source.message and self.inventory is not None {
            self.message = source.message;
        }
        if source.cue {
            self.cues.append(source.cue);
        }
        # Q2 trigger_elevator_use reads the caller's pathtarget (`other`).
        if source.pathtarget {
            for recipient in [source->:Targets:->][?:Signal] {
                if recipient.routed {
                    recipient.calls.append(source.pathtarget);
                }
            }
        }
        for victim in [source->:Kills:->][?:Signal] {
            victim.killed = True;
            victim.enabled = False;
            victim.queued = [];
            victim.timer_running = False;
            victim.pending = 0;
        }
    }

    can deliver with Signal entry {
        if here.killed
            or (not here.enabled and not (self.emit and self.scheduled))
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
            # target_crosslevel_target fires only once its unit flags are all set.
            if here.require_flags {
                flags = quantity(self.inventory, "unit_flags") if self.inventory is not None else 0;
                if flags & here.require_flags != here.require_flags {
                    return;
                }
            }
            self.scheduled = False;
            self.announce(here);
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
            self.announce(here);
            visit [here->:Targets:->];
        } elif here.relay {
            # target_crosslevel_trigger records its flags for the rest of the unit.
            if here.grant_flags and self.inventory is not None {
                old = quantity(self.inventory, "unit_flags");
                self.inventory spawn AdjustInventory(
                    kind="unit_flags", amount=(old | here.grant_flags) - old, capacity=255
                );
            }
            # Q2 TRIGGERED triggers: the first use only enables touching.
            if here.armable and not here.armed {
                here.armed = True;
                return;
            }
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
                    self.message = counter_text(here.counter_style, here.remaining);
                    return;
                }
                self.message = ""
                    if here.counter_style == "silent"
                    else "Sequence completed!";
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
            self.announce(here);
            visit [here->:Targets:->];
        } else {
            here.pending += 1;
        }
    }
}


# Collect first, deliver second: newly scheduled events never age in this tick.
walker SignalTick {
    has dt: float,
        inventory: Inventory | None = None,
        ready: list[ReadyUse] = [],
        message: str = "",
        cues: list[str] = [];

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
                scheduled=event.scheduled,
                inventory=event.inventory if event.inventory is not None else self.inventory
            );
            if fired.message {
                self.message = fired.message;
            }
            self.cues.extend(fired.cues);
        }
    }
}
