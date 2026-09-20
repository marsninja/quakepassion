"""Map-defined campaign exit requests, separate from application loading."""
import from .world { World }
import from .signals { Signal, HasSignal }
import from .triggers { trigger_volume }
import from ..formats.bsp { Bsp }
import from ..formats.q1.collision { build_collision }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

edge HasExit {}
node LevelExit {
    has destination: str,
        activation: Signal = Signal(),
        volume: CollisionMap = CollisionMap(),
        contact: bool = False,
        cooldown: float = 0.0;
}

walker ExitTick {
    has start: Vec3,
        finish: Vec3,
        dt: float,
        touching: bool = True,
        request: str = "";

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
        if here.contact {
            hit = here.volume.trace(self.start, self.finish);
            active = active or hit.start_solid or hit.fraction < 1.0;
        }
        if active {
            self.request = here.destination;
            here.cooldown = 1.0;
        }
    }
}

# Keep the unit marker and spawnpoint in the request; only the asset name is normalized.
def exit_map(request: str) -> str {
    name = request.split("$")[0];
    if name.startswith("*") {
        name = name[1:];
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
        if not destination
            or fields.get("killtarget", "")
            or fields.get("target", "")
            or float(fields.get("delay", "0")) != 0.0 {
            continue;
        }
        allowed = 3841 if bsp.game == "q1" else 7936;
        if int(fields.get("spawnflags", "0")) & ~allowed {
            continue;
        }
        try {
            exit_map(destination);
            exit_spawn(destination);
        } except ValueError {
            continue;
        }
        signal = Signal(entities=[index]);
        portal = LevelExit(destination=destination, activation=signal, contact=contact);
        if contact {
            model = fields.get("model", "");
            if not model.startswith("*") or fields.get("targetname", "") {
                continue;
            }
            portal.volume = trigger_volume(volumes, int(model[1:]));
            if not portal.volume.hulls {
                continue;
            }
        }
        world +>:HasSignal:+> signal;
        world +>:HasExit:+> portal;
    }
}
