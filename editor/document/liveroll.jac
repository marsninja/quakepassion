"""What a played game holds besides its player, called over: its opponents,
doors and pickups, each in the order the world keeps them, so that a number
means the same thing from one look to the next."""

import from engine.world.world { World }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.doors { Door, HasDoor }
import from engine.world.pickups { Pickup, HasPickup }

"""Walks out from a world to everything of those kinds it holds."""
walker LiveRoll {
    has opponents: list[Opponent] = [],
        doors: list[Door] = [],
        pickups: list[Pickup] = [];

    can begin with World entry {
        visit [here->:HasOpponent:->];
        visit [here->:HasDoor:->];
        visit [here->:HasPickup:->];
    }

    can call_opponent with Opponent entry {
        self.opponents.append(here);
    }

    can call_door with Door entry {
        self.doors.append(here);
    }

    can call_pickup with Pickup entry {
        self.pickups.append(here);
    }
}

def:priv whole(value: float) -> str {
    return str(int(round(value)));
}

"""An opponent in a line: what it is by its model, where, how it is."""
def opponent_words(number: int, found: Opponent) -> str {
    model = found.rule.model.split("/")[-1] if found.rule.model else "-";
    return "opponent " + str(number) + " model=" + model + " at=" + whole(found.pos.x) + "," + whole(found.pos.y) + ","
        + whole(found.pos.z) + " health=" + str(found.health) + " dormant=" + ("1" if found.dormant else "0");
}

"""A door in a line: its map model, what it is doing, and its names."""
def door_words(number: int, found: Door) -> str {
    return "door " + str(number) + " model=*" + str(found.model) + " kind=" + found.kind + " state=" + found.state
        + " enabled=" + ("1" if found.enabled else "0") + " names=" + (",".join(found.names) if found.names else "-");
}

"""A pickup in a line: its class and where it lies."""
def pickup_words(number: int, found: Pickup) -> str {
    return "pickup " + str(number) + " class=" + (found.rule.classname if found.rule.classname else found.rule.kind)
        + " at=" + whole(found.pos.x) + "," + whole(found.pos.y) + "," + whole(found.pos.z);
}
