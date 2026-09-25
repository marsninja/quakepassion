"""Map-defined campaign exit requests, separate from application loading."""
import from .world { World }
import from .signals { Signal, HasSignal, Fire, note_chain }
import from .inventory { Inventory }
import from .triggers { trigger_volume }
import from ..formats.bsp { Bsp }
import from ..formats.q1.collision { build_collision }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

edge HasExit: World --> LevelExit {}
node LevelExit {
    has destination: str,
        activation: Signal = Signal(),
        volume: CollisionMap = CollisionMap(),
        contact: bool = False,
        intermission: bool = True,
        cooldown: float = 0.0;
}

walker ExitTick {
    has start: Vec3,
        finish: Vec3,
        dt: float,
        touching: bool = True,
        inventory: Inventory | None = None,
        request: str = "",
        intermission: bool = True,
        message: str = "",
        cues: list[str] = [];

    can begin with World entry {
        if self.dt > 0.0 and self.touching {
            visit [here->:HasExit:->];
        }
    }

    can check with LevelExit entry {
        if self.dt <= 0.0 or not self.touching or self.request {
            return;
        }
        here.cooldown = max(0.0, here.cooldown - self.dt);
        if here.cooldown > 0.0 or not here.activation.enabled {
            return;
        }
        active = here.activation.pending > 0;
        here.activation.pending = 0;
        touched = False;
        if here.contact {
            hit = here.volume.trace(self.start, self.finish);
            touched = hit.start_solid or hit.fraction < 1.0;
        }
        if active or touched {
            self.request = here.destination;
            self.intermission = here.intermission;
            here.cooldown = 1.0;
        }
        # Q1 changelevel_touch: SUB_UseTargets before the level changes.
        if touched {
            fired = here.activation spawn Fire(inventory=self.inventory);
            self.message = fired.message;
            self.cues.extend(fired.cues);
        }
    }
}

# A leading cinematic ("name.cin+") is skipped; "victory.pcx" ends the campaign.
def exit_cinematic(request: str) -> str {
    name = request.split("$")[0];
    if "+" in name {
        prefix = name.split("+")[0];
        if prefix.endswith(".cin") {
            return prefix[:-4];
        }
    }
    return "";
}

# Keep the unit marker and spawnpoint in the request; only the asset name is normalized.
def exit_map(request: str) -> str {
    name = request.split("$")[0];
    if "+" in name {
        name = name.split("+")[-1];
    }
    if name.startswith("*") {
        name = name[1:];
    }
    if name.endswith(".pcx") and "/" not in name and "\\" not in name {
        return name;
    }
    if not name or "/" in name or "\\" in name or "." in name {
        raise ValueError("Invalid destination map");
    }
    return name;
}

def exit_spawn(request: str) -> str {
    parts = request.split("$");
    if len(parts) > 2 {
        raise ValueError("Invalid destination spawnpoint");
    }
    return parts[1] if len(parts) == 2 else "";
}

def load_exits(world: World, bsp: Bsp) {
    volumes = CollisionMap();
    if bsp.game == "q1" {
        volumes = build_collision(bsp, triggers=True);
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        kind = fields.get("classname", "");
        contact = bsp.game == "q1" and kind == "trigger_changelevel";
        if not contact and not (bsp.game == "q2" and kind == "target_changelevel") {
            continue;
        }
        destination = fields.get("map", "");
        # Q2 use_target_changelevel ignores the exit's own target, killtarget,
        # delay and spawnflags; Q1 changelevel_touch fires its targets itself.
        if not destination {
            note_chain(world, index, "exit without a map");
            continue;
        }
        try {
            exit_map(destination);
            exit_spawn(destination);
        } except ValueError {
            note_chain(world, index, "exit with an invalid map " + destination);
            continue;
        }
        signal = Signal(entities=[index]);
        portal = LevelExit(
            destination=destination,
            activation=signal,
            contact=contact,
            # Q1 NO_INTERMISSION (1) goes straight to the next map.
            intermission=not (contact and int(fields.get("spawnflags", "0")) & 1 != 0)
        );
        if contact {
            model = fields.get("model", "");
            if model.startswith("*") {
                portal.volume = trigger_volume(volumes, int(model[1:]));
            }
            if not portal.volume.hulls {
                note_chain(world, index, "exit without a trigger volume");
                continue;
            }
        }
        world +>:HasSignal:+> signal;
        world +>:HasExit:+> portal;
    }
}
