"""What a player has to make happen to get by a mover: the objectives read
off the level's own activation graph, which the level graph's openers are
made of (`engine/level/extract.jac`).

A mover that is not where a traveller needs it and will not come by itself
(a door that opens by a button, a floor lowered by a switch, a door locked
by a key) wants an objective first:

- a key to pick up (Quake's silver and gold keys, Quake II's keys);
- a door or button to shoot (one with health);
- something that fires the mover: found by the `FindActions` walker, which
  goes backwards over the `Targets` edges into the mover's `Signal` (and the
  `Activates` edges of the triggers that fire it directly), through relays,
  delays and counters, to what a player can do: a button to press, a
  trigger to stand in or shoot, a monster to kill, an item to pick up.

An exit fired by its chain rather than touched is planned the same way."""
import from .world { World, Player }
import from .doors { Door, HasDoor, DoorMember, door_parts, door_starts_open }
import from .signals { Signal, Targets }
import from .triggers { TouchTrigger, HasTrigger, Activates }
import from .combat { Opponent, HasOpponent }
import from .pickups { Pickup, HasPickup }
import from .inventory { quantity }
import from .exits { LevelExit }
import from .trains { Train, HasTrain, secret_open_motion }
import from .bot_travel { BODY_REACH_BELOW, BODY_REACH_ABOVE }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

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
        # A secret door it is to open (one of the track movers).
        train: Train | None = None,
        body: Opponent | None = None,
        item: Pickup | None = None,
        # The mover (BSP model) it is to get by, 0 for none.
        mover: int = 0,
        # Where a body's origin does it, when that is a volume (a trigger to
        # stand in, a button to walk into).
        box: AABB | None = None,
        # What is shot at, when it is a solid (a door, a secret door, a
        # button): a shot that ends on it hits it, however thick it is.
        aim_box: AABB | None = None,
        # The counter it is one of the inputs of (a trigger_counter that
        # fires once enough of them have), when it is.
        counter: Signal | None = None;
}

"""Where a player's origin picks an item up: its box (16 a side, 56 tall
from the item's origin) touching the player's (16 a side, 24 below and 32
above the origin)."""
def objective_item_box(item: Pickup) -> AABB {
    return AABB(mins=item.pos.sub(Vec3(x=32.0, y=32.0, z=32.0)), maxs=item.pos.add(Vec3(x=32.0, y=32.0, z=80.0)));
}

"""The middle of a trigger's volume."""
def objective_volume_center(trigger: TouchTrigger) -> Vec3 | None {
    if not trigger.volume.bounds {
        return None;
    }
    box = trigger.volume.bounds[0];
    return box.mins.add(box.maxs).scale(0.5);
}

"""Whether a door is where a traveller gets by: open, opening, or, for one
that starts open (START_OPEN: it closes as it moves), still at rest; a plat
once it is going."""
def objective_door_open(door: Door) -> bool {
    # A plat waiting where it was drawn until something sets it going (Q1
    # func_plat with a targetname) is no way by until then.
    if door.kind == "platform" {
        return door.state != "locked";
    }
    if door_starts_open(door) {
        return door.position <= 0.01;
    }
    return door.position >= 0.99 or door.state in ["opening", "open"];
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
            found.append(Objective(kind="shoot", point=middle, aim=middle, why=why, signal=source, aim_box=trigger.volume.bounds[0] if trigger.volume.bounds else None));
        } elif trigger.players and trigger.touchable {
            box = trigger.volume.bounds[0];
            found.append(Objective(kind="touch", point=middle, why=why, signal=source, box=box));
        }
    }
    for part in door_parts(world) {
        # A button already in (one that stays in, or not yet back out) has
        # done what it does; a counter it feeds wants the others.
        if part.activation is not source or part.kind != "button" or part.position > 0.0 or part.state != "closed" {
            continue;
        }
        box = part.bounds;
        middle = box.mins.add(box.maxs).scale(0.5).add(part.rest);
        kind = "shoot" if part.health > 0 else "press";
        # Pressed by the player's box touching it: its origin within the
        # button's box grown by the player's.
        reach = AABB(
            mins=box.mins.add(part.rest).sub(BODY_REACH_BELOW),
            maxs=box.maxs.add(part.rest).add(BODY_REACH_ABOVE)
        );
        found.append(
            Objective(kind=kind, point=middle, aim=middle, why=why, signal=source, door=part, box=reach if kind == "press" else None)
        );
    }
    # A door that fires its targets as it opens (Quake's func_door with a
    # target, e4m6's gold door setting a plat going): shot open when it
    # takes a shot, else opened by a touch, with the keys it wants (a door
    # fired from elsewhere is looked behind).
    for part in door_parts(world) {
        if part.activation is not source or part.kind != "door" or not part.fire_on_start or part.state != "closed" {
            continue;
        }
        if part.health > 0 {
            box = part.bounds;
            middle = box.mins.add(box.maxs).scale(0.5).add(part.rest);
            found.append(Objective(kind="shoot", point=middle, aim=middle, why=why, signal=source, door=part, aim_box=AABB(mins=box.mins.add(part.rest), maxs=box.maxs.add(part.rest))));
        } elif part.automatic {
            middle = part.trigger.mins.add(part.trigger.maxs).scale(0.5);
            found.append(Objective(kind="touch", point=middle, why=why, signal=source, door=part, box=part.trigger));
        }
    }
    for body in [world->:HasOpponent:->][?:Opponent] {
        if body.activation is source and body.health > 0 {
            found.append(Objective(kind="kill", point=body.pos, aim=body.pos, why=why, body=body, signal=source));
        }
    }
    for item in [world->:HasPickup:->][?:Pickup] {
        if item.activation is source and item.active {
            found.append(
                Objective(kind="pickup", point=item.pos, why=why, item=item, signal=source, box=objective_item_box(item))
            );
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
        first = len(self.found);
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
        # A counter: what fires it directly is one of its inputs.
        if here.remaining > 0 {
            for objective in self.found[first:] {
                if objective.counter is None {
                    objective.counter = here;
                }
            }
        }
        visit behind;
    }
}

"""The items that would give the key `key`, on the map now."""
def objective_key_items(world: World, key: str, why: str) -> list[Objective] {
    found: list[Objective] = [];
    for item in [world->:HasPickup:->][?:Pickup] {
        if item.active and item.rule.kind == key {
            found.append(Objective(kind="pickup", point=item.pos, why=why, item=item, box=objective_item_box(item)));
        }
    }
    return found;
}

"""The secret door (a track mover of kind "secret") with BSP `model`, or None."""
def objective_secret(world: World, model: int) -> Train | None {
    for train in [world->:HasTrain:->][?:Train] {
        if train.model == model and train.kind == "secret" {
            return train;
        }
    }
    return None;
}

"""Whether a secret door stands fully open: at the third point of its track
of four (the pose the navigation is compiled in), not part way there."""
def objective_secret_open(train: Train) -> bool {
    return train.motion.sub(secret_open_motion(train)).length() < 2.0;
}

"""What opens a secret door that is shut: a shot when it takes one, else
what fires it."""
def secret_objectives(world: World, train: Train, model: int) -> list[Objective] {
    if train.motion.length() > 1.0 {
        return [];
    }
    why = "secret door " + str(model);
    middle = train.bounds.mins.add(train.bounds.maxs).scale(0.5);
    found: list[Objective] = [];
    if train.shootable {
        found.append(Objective(kind="shoot", point=middle, aim=middle, why=why, train=train, aim_box=train.bounds));
    }
    search = train.activation spawn FindActions(world=world, why=why);
    for action in search.found {
        action.train = train;
        found.append(action);
    }
    return found;
}

"""What sets a train going that waits to be fired (a Quake func_train with a
targetname stands where it was drawn until then): what fires it. Nothing
for one already running."""
def train_objectives(world: World, train: Train) -> list[Objective] {
    if train.running or train.started {
        return [];
    }
    search = train.activation spawn FindActions(world=world, why="train " + str(train.model));
    for action in search.found {
        action.mover = train.model;
    }
    return search.found;
}

"""What the player must do before the mover with BSP `model` lets it by:
nothing (an empty list) when it is where it needs to be or comes by itself.
Each choice is an objective; the caller picks the one it reaches."""
def mover_objectives(world: World, model: int, player: Player, resting: bool = False) -> list[Objective] {
    leader = objective_mover(world, model);
    if leader is None {
        secret = objective_secret(world, model);
        found_secret = secret_objectives(world, secret, model) if secret is not None else [];
        for action in found_secret {
            action.mover = model;
        }
        return found_secret;
    }
    if leader.kind == "button" {
        return [];
    }
    found_all = mover_objectives_of(world, leader, model, player, resting);
    for action in found_all {
        action.mover = model;
    }
    return found_all;
}

def:priv mover_objectives_of(world: World, leader: Door, model: int, player: Player, resting: bool) -> list[Objective] {
    why = "mover " + str(model);
    if resting and door_starts_open(leader) {
        # Walked on where the door closes to (a bridge drawn out): what
        # closes it, until it has.
        if leader.position >= 0.99 {
            return [];
        }
    } elif objective_door_open(leader) {
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
        return [Objective(kind="shoot", point=middle, aim=middle, why=why, door=leader, aim_box=AABB(mins=box.mins.add(leader.rest), maxs=box.maxs.add(leader.rest)))];
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
    if leader is None {
        secret = objective_secret(world, model);
        return secret is not None and not objective_secret_open(secret);
    }
    if leader.kind == "button" {
        return False;
    }
    if objective_door_open(leader) {
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
