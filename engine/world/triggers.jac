"""Brush-contact activation of named doors through shared graph relationships."""
import from .world { World }
import from .doors { Door, resolve_targets }
import from .signals { Signal, Fire }
import from ..formats.bsp { Bsp }
import from ..formats.q1.collision { build_collision }
import from ..formats.brush_collision { build_brush_collision }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

edge HasTrigger: World --> TouchTrigger {}
edge Activates: TouchTrigger --> Door | Signal {}

node TouchTrigger {
    has model: int,
        volume: CollisionMap,
        interval: float,
        once: bool = False,
        enabled: bool = True,
        cooldown: float = 0.0,
        activations: int = 0;
}

walker Activate {
    can targets with TouchTrigger entry {
        visit [here->:Activates:->];
    }

    can signal with Signal entry {
        here spawn Fire(emit=False);
    }

    can request with Door entry {
        here.requested = True;
    }
}

walker TriggerTick {
    has start: Vec3,
        finish: Vec3,
        dt: float,
        touching: bool = True,
        top_drop: float = 0.0;

    can start_world with World entry {
        if self.dt > 0.0 {
            visit [here->:HasTrigger:->];
        }
    }

    can contact with TouchTrigger entry {
        if self.dt <= 0.0 or not here.enabled {
            return;
        }
        here.cooldown = max(0.0, here.cooldown - self.dt);
        if not self.touching or here.cooldown > 0.0 {
            return;
        }
        hit = here.volume.trace(self.start, self.finish, top_drop=self.top_drop);
        if hit.start_solid or hit.fraction < 1.0 {
            here spawn Activate();
            here.activations += 1;
            here.cooldown = here.interval;
            if here.once {
                here.enabled = False;
            }
        }
    }
}

def load_triggers(world: World, bsp: Bsp) {
    volumes = build_collision(bsp, triggers=True)
        if bsp.game == "q1"
        else build_brush_collision(bsp, triggers=True);
    for entity in bsp.entities {
        fields = entity.fields;
        kind = fields.get("classname", "");
        target = fields.get("target", "");
        if kind not in ["trigger_once", "trigger_multiple"] or not target {
            continue;
        }
        allowed = 3840 if bsp.game == "q1" else (7936 if bsp.game == "q2" else 0);
        if int(fields.get("spawnflags", "0")) & ~allowed
            or fields.get("targetname", "")
            or fields.get("killtarget", "")
            or float(fields.get("health", "0")) != 0.0
            or float(fields.get("delay", "0")) != 0.0
            or float(fields.get("random", "0")) != 0.0
            or float(fields.get("angle", "0")) != 0.0
            or fields.get("angles", "0 0 0") != "0 0 0" {
            continue;
        }
        name = fields.get("model", "");
        if not name.startswith("*") {
            continue;
        }
        model = int(name[1:]);
        targets = resolve_targets(world, bsp, target);
        if not targets {
            continue;
        }
        volume = trigger_volume(volumes, model);
        if not volume.hulls {
            continue;
        }
        interval = float(fields.get("wait", "0"));
        if interval == 0.0 {
            interval = 0.5 if bsp.game == "q3" else 0.2;
        }
        trigger = TouchTrigger(
            model=model,
            volume=volume,
            interval=max(0.0, interval),
            once=kind == "trigger_once" or interval < 0.0
        );
        for door in targets {
            trigger +>:Activates:+> door;
        }
        world +>:HasTrigger:+> trigger;
    }
}


def trigger_volume(volumes: CollisionMap, model: int) -> CollisionMap {
    volume = CollisionMap(eye_height=volumes.eye_height);
    for i in range(len(volumes.models)) {
        if volumes.models[i] == model {
            volume.hulls.append(volumes.hulls[i]);
            volume.offsets.append(volumes.offsets[i]);
            if len(volumes.bounds) == len(volumes.hulls) {
                volume.bounds.append(volumes.bounds[i]);
            }
        }
    }
    volume.reindex();
    return volume;
}
