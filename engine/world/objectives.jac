"""What the player bot has to make happen to get on: the objectives it
plans from the level's own activation graph (issue #88, milestone 6).

The navigation compiles doors open and plats up, so a route runs through
movers as though they were where a traveller needs them. When the route
reaches a mover that is not there and will not come by itself (a door that
opens by a button, a floor lowered by a switch, a door locked by a key), the
bot needs an objective first:

- a key to pick up (Quake's silver and gold keys, Quake II's keys);
- a door or button to shoot (one with health);
- something that fires the mover: found by the `FindActions` walker, which
  goes backwards over the `Targets` edges into the mover's `Signal` (and the
  `Activates` edges of the triggers that fire it directly), through relays,
  delays and counters, to what a player can do: a button to press, a
  trigger to stand in or shoot, a monster to kill, an item to pick up.

An exit fired by its chain rather than touched is planned the same way."""
import from .world { World, Player }
import from .doors { Door, HasDoor, DoorMember }
import from .signals { Signal, Targets }
import from .triggers { TouchTrigger, HasTrigger, Activates }
import from .combat { Opponent, HasOpponent }
import from .pickups { Pickup, HasPickup }
import from .inventory { quantity }
import from .exits { LevelExit }
import from ..math.vec3 { Vec3 }

"""One thing to do: `kind` is "press" (walk into a button), "touch" (stand
in a trigger), "shoot" (a button, door or trigger with health), "kill" (a
monster whose death fires the chain) or "pickup" (an item: a key, or one
whose pickup fires the chain). `point` is where to go; `aim` what to shoot."""
node Objective {
    has kind: str,
        point: Vec3,
        aim: Vec3 = Vec3(),
        why: str = "",
        signal: Signal | None = None,
        door: Door | None = None,
        body: Opponent | None = None,
        item: Pickup | None = None,
        # The mover (BSP model) it is to get by, 0 for none.
        mover: int = 0,
        # How many times its signal had fired, and when it was taken up.
        fired: int = 0,
        started: float = 0.0;

    """Whether it is done: the signal fired since it was taken up, the
    monster dead, the item taken, the door moving."""
    def done(player: Player) -> bool {
        if self.kind == "kill" {
            body = self.body;
            return body is None or body.health <= 0;
        }
        if self.kind == "pickup" {
            item = self.item;
            return item is None or not item.active;
        }
        signal = self.signal;
        if signal is not None and signal.fired > self.fired {
            return True;
        }
        door = self.door;
        return door is not None and (door.position > 0.0 or door.state not in ["closed", "locked"]);
    }
}

edge Requires: Objective --> Objective {}

"""The middle of a trigger's volume."""
def objective_volume_center(trigger: TouchTrigger) -> Vec3 | None {
    if not trigger.volume.bounds {
        return None;
    }
    box = trigger.volume.bounds[0];
    return box.mins.add(box.maxs).scale(0.5);
}

"""Every door, plat and button, members of teams included."""
def objective_movers(world: World) -> list[Door] {
    found: list[Door] = [];
    for leader in [world->:HasDoor:->][?:Door] {
        found.append(leader);
        for part in [leader->:DoorMember:->][?:Door] {
            if part not in found {
                found.append(part);
            }
        }
    }
    return found;
}

"""The leader of the team the mover with BSP `model` is in, or None."""
def objective_mover(world: World, model: int) -> Door | None {
    for leader in [world->:HasDoor:->][?:Door] {
        if leader.model == model {
            return leader;
        }
        for part in [leader->:DoorMember:->][?:Door] {
            if part.model == model {
                return leader;
            }
        }
    }
    return None;
}

"""What a player can do that fires `source` (the signal of the thing it
belongs to): nothing when it is a relay, a delay or a counter to look
behind."""
def objective_owner_actions(world: World, source: Signal, why: str) -> list[Objective] {
    found: list[Objective] = [];
    for trigger in [world->:HasTrigger:->][?:TouchTrigger] {
        # A trigger that fires once and has: nothing more to get from it.
        if trigger.signal is not source or not trigger.enabled or (trigger.once and trigger.activations > 0) {
            continue;
        }
        middle = objective_volume_center(trigger);
        if middle is None {
            continue;
        }
        if trigger.health > 0 {
            found.append(Objective(kind="shoot", point=middle, aim=middle, why=why, signal=source));
        } elif trigger.players and trigger.touchable {
            found.append(Objective(kind="touch", point=middle, why=why, signal=source));
        }
    }
    for part in objective_movers(world) {
        # A button already in (one that stays in, or not yet back out) has
        # done what it does; a counter it feeds wants the others.
        if part.activation is not source or part.kind != "button" or part.position > 0.0 or part.state != "closed" {
            continue;
        }
        box = part.bounds;
        middle = box.mins.add(box.maxs).scale(0.5).add(part.rest);
        kind = "shoot" if part.health > 0 else "press";
        found.append(Objective(kind=kind, point=middle, aim=middle, why=why, signal=source, door=part));
    }
    for body in [world->:HasOpponent:->][?:Opponent] {
        if body.activation is source and body.health > 0 {
            found.append(Objective(kind="kill", point=body.pos, aim=body.pos, why=why, body=body, signal=source));
        }
    }
    for item in [world->:HasPickup:->][?:Pickup] {
        if item.activation is source and item.active {
            found.append(Objective(kind="pickup", point=item.pos, why=why, item=item, signal=source));
        }
    }
    return found;
}

"""Backwards from a signal to what a player can do to fire it: through the
`Targets` edges into it, and the triggers that `Activates` it directly, past
relays, delays and counters and on behind anything that can itself be fired,
up to sixty-four signals deep. Every action found is a choice."""
walker FindActions {
    has world: World,
        why: str = "",
        found: list[Objective] = [],
        seen: list[Signal] = [];

    can trace with Signal entry {
        if here in self.seen or len(self.seen) > 64 {
            return;
        }
        self.seen.append(here);
        for trigger in [here<-:Activates:<-][?:TouchTrigger] {
            source = trigger.signal;
            if source is not None {
                self.found.extend(objective_owner_actions(self.world, source, self.why));
            }
        }
        # What fires each source is looked at too, not only relays: a
        # trigger out of reach may also be fired by a button that uses it.
        behind: list[Signal] = [];
        for source in [here<-:Targets:<-][?:Signal] {
            self.found.extend(objective_owner_actions(self.world, source, self.why));
            behind.append(source);
        }
        visit behind;
    }
}

"""The items that would give the key `key`, on the map now."""
def objective_key_items(world: World, key: str, why: str) -> list[Objective] {
    found: list[Objective] = [];
    for item in [world->:HasPickup:->][?:Pickup] {
        if item.active and item.rule.kind == key {
            found.append(Objective(kind="pickup", point=item.pos, why=why, item=item));
        }
    }
    return found;
}

"""What the player must do before the mover with BSP `model` lets it by:
nothing (an empty list) when it is where it needs to be or comes by itself.
Each choice is an objective; the caller picks the one it reaches."""
def mover_objectives(world: World, model: int, player: Player) -> list[Objective] {
    leader = objective_mover(world, model);
    if leader is None or leader.kind == "button" {
        return [];
    }
    found_all = mover_objectives_of(world, leader, model, player);
    for action in found_all {
        action.mover = model;
    }
    return found_all;
}

def:priv mover_objectives_of(world: World, leader: Door, model: int, player: Player) -> list[Objective] {
    why = "mover " + str(model);
    if leader.position >= 0.99 or leader.state in ["opening", "open"] {
        return [];
    }
    if leader.keys and not leader.unlocked {
        missing = [key for key in leader.keys if quantity(player.inventory, key) <= 0];
        if not missing {
            return [];
        }
        found: list[Objective] = [];
        for key in missing {
            found.extend(objective_key_items(world, key, why + " needs " + key));
        }
        return found;
    }
    if leader.health > 0 {
        box = leader.bounds;
        middle = box.mins.add(box.maxs).scale(0.5).add(leader.rest);
        return [Objective(kind="shoot", point=middle, aim=middle, why=why, door=leader)];
    }
    if leader.automatic and leader.kind != "platform" {
        return [];
    }
    if leader.kind == "platform" and leader.state != "locked" {
        return [];
    }
    search = leader.activation spawn FindActions(world=world, why=why);
    for action in search.found {
        if action.door is None {
            action.door = leader;
        }
    }
    return search.found;
}

"""Whether the mover with BSP `model` stands in the way of a player: not
where travel needs it and not coming by itself (shut by a key the player
lacks, fired from elsewhere, shot open, a plat held at the top)."""
def mover_blocked(world: World, model: int, player: Player) -> bool {
    leader = objective_mover(world, model);
    if leader is None or leader.kind == "button" {
        return False;
    }
    if leader.position >= 0.99 or leader.state in ["opening", "open"] {
        return False;
    }
    if leader.keys and not leader.unlocked {
        return len([key for key in leader.keys if quantity(player.inventory, key) <= 0]) > 0;
    }
    if leader.health > 0 {
        return True;
    }
    if leader.kind == "platform" {
        return leader.state == "locked";
    }
    return not leader.automatic;
}

"""What fires an exit that is not touched (Quake II's target_changelevel at
the end of a chain)."""
def exit_objectives(world: World, portal: LevelExit) -> list[Objective] {
    search = portal.activation spawn FindActions(world=world, why="exit to " + portal.destination);
    return search.found;
}
