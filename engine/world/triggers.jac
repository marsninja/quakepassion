"""Brush-contact activation of named doors through shared graph relationships."""
import math;
import from .world { World, Player }
import from .combat { Opponent, HasOpponent }
import from .doors { Door, resolve_targets, authored_cue }
import from .signals { Signal, Fire, HasSignal, Targets }
import from ..formats.bsp { Bsp }
import from ..formats.q1.collision { build_collision }
import from ..formats.brush_collision { build_brush_collision }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3, forward_from }

edge HasTrigger: World --> TouchTrigger {}
edge Activates: TouchTrigger --> Door | Signal {}

node TouchTrigger {
    has model: int,
        volume: CollisionMap,
        interval: float,
        once: bool = False,
        enabled: bool = True,
        cooldown: float = 0.0,
        activations: int = 0,
        signal: Signal | None = None,
        facing: Vec3 = Vec3(),
        touchable: bool = True,
        health: int = 0,
        max_health: int = 0,
        hulls: list[int] = [],
        skill: int = -1,
        monsters: bool = False,
        players: bool = True;
}

walker Activate {
    has player: Player | None = None,
        message: str = "",
        cues: list[str] = [];

    can targets with TouchTrigger entry {
        visit [here->:Activates:->];
    }

    can signal with Signal entry {
        fired = here spawn Fire(
            emit=False,
            inventory=self.player.inventory if self.player is not None else None
        );
        if fired.message {
            self.message = fired.message;
        }
        self.cues.extend(fired.cues);
    }

    can request with Door entry {
        here.requested = True;
    }
}

"""A trigger's own signal gates it: killtargets retire it, Q2 TRIGGERED ones wait
to be armed, and one-shot relays close once they fire."""
def trigger_ready(trigger: TouchTrigger) -> bool {
    relay = trigger.signal;
    if relay is None {
        return trigger.enabled;
    }
    if relay.killed {
        trigger.enabled = False;
    }
    return trigger.enabled and relay.armed;
}

walker TriggerTick {
    has start: Vec3,
        finish: Vec3,
        dt: float,
        touching: bool = True,
        top_drop: float = 0.0,
        player: Player | None = None,
        message: str = "",
        cues: list[str] = [],
        skill: int = -1,
        world: World | None = None;

    can start_world with World entry {
        self.world = here;
        if self.dt > 0.0 {
            visit [here->:HasTrigger:->];
        }
    }

    can contact with TouchTrigger entry {
        if self.dt <= 0.0 or not trigger_ready(here) {
            return;
        }
        here.cooldown = max(0.0, here.cooldown - self.dt);
        if here.health > 0 and here.cooldown <= 0.0 {
            here.health = here.max_health;
        }
        if not here.touchable or here.cooldown > 0.0 {
            return;
        }
        if self.touching and here.players {
            # Directional triggers only fire for players facing along them.
            player = self.player;
            facing_ok = here.facing.length() <= 0.0
                or player is None
                or forward_from(player.yaw, 0.0).dot(here.facing) >= 0.0;
            hit = here.volume.trace(self.start, self.finish, top_drop=self.top_drop);
            if facing_ok and (hit.start_solid or hit.fraction < 1.0) {
                if here.skill >= 0 {
                    self.skill = here.skill;
                    return;
                }
                fire_trigger(here, player, self);
                return;
            }
        }
        # Q2 MONSTER triggers also fire for monsters standing in them
        # (Touch_Multi); their messages go to no one.
        world = self.world;
        if here.monsters and world is not None {
            for enemy in [world->:HasOpponent:->][?:Opponent] {
                if enemy.health <= 0 or enemy.dormant {
                    continue;
                }
                origin = enemy.pos.sub(Vec3(z=enemy.eye_height));
                if here.volume.trace(origin, origin).start_solid {
                    activated = here spawn Activate();
                    self.cues.extend(activated.cues);
                    here.activations += 1;
                    here.cooldown = here.interval;
                    if here.once {
                        here.enabled = False;
                    }
                    return;
                }
            }
        }
    }
}

def fire_trigger(trigger: TouchTrigger, player: Player | None, tally: TriggerTick | None = None) {
    activated = trigger spawn Activate(player=player);
    if tally is not None {
        if activated.message {
            tally.message = activated.message;
        }
        tally.cues.extend(activated.cues);
    }
    trigger.activations += 1;
    trigger.cooldown = trigger.interval;
    if trigger.once {
        trigger.enabled = False;
    }
}

"""Shootable triggers (Q1 `health`): solid until destroyed, then they fire."""
walker ShootTrigger {
    has model: int = -1,
        amount: int = 0,
        origin: Vec3 = Vec3(),
        radius: float = 0.0,
        collision: CollisionMap | None = None,
        player: Player | None = None,
        message: str = "",
        cues: list[str] = [];

    can begin with World entry {
        visit [here->:HasTrigger:->];
    }

    can hit with TouchTrigger entry {
        if here.max_health <= 0 or here.health <= 0 or not trigger_ready(here) {
            return;
        }
        amount = self.amount;
        if self.radius > 0.0 {
            if not here.volume.bounds {
                return;
            }
            box = here.volume.bounds[0];
            center = box.mins.lerp(box.maxs, 0.5);
            distance = center.sub(self.origin).length();
            if distance >= self.radius {
                return;
            }
            amount = int(float(self.amount) - distance * 0.5);
        } elif self.model != here.model {
            return;
        }
        if amount <= 0 {
            return;
        }
        here.health -= amount;
        if here.health > 0 {
            return;
        }
        here.health = 0;
        activated = here spawn Activate(player=self.player);
        if activated.message {
            self.message = activated.message;
        }
        self.cues.extend(activated.cues);
        here.activations += 1;
        here.cooldown = max(0.0, here.interval);
        collision = self.collision;
        if here.once and collision is not None {
            here.enabled = False;
            for index in here.hulls {
                collision.set_disabled(index, True);
            }
        }
    }
}

def load_triggers(world: World, bsp: Bsp, collision: CollisionMap | None = None) {
    volumes = build_collision(bsp, triggers=True)
        if bsp.game == "q1"
        else build_brush_collision(bsp, triggers=True);
    added = False;
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        kind = fields.get("classname", "");
        target = fields.get("target", "");
        secret = kind == "trigger_secret" and bsp.game == "q1";
        setskill = kind == "trigger_setskill" and bsp.game == "q1";
        if not secret
            and not setskill
            and kind not in ["trigger_once", "trigger_multiple", "trigger_onlyregistered"] {
            continue;
        }
        flags = int(fields.get("spawnflags", "0"));
        allowed = 3840 if bsp.game == "q1" else (7936 if bsp.game == "q2" else 0);
        if bsp.game == "q1" {
            allowed |= 1;
        } elif bsp.game == "q2" {
            # TRIGGERED, plus MONSTER and NOT_PLAYER for who may touch it.
            allowed |= 7;
        }
        if flags & ~allowed {
            continue;
        }
        name = fields.get("model", "");
        if not name.startswith("*") {
            continue;
        }
        model = int(name[1:]);
        relay: Signal | None = None;
        for signal in [world->:HasSignal:->][?:Signal] {
            if signal.relay and index in signal.entities {
                relay = signal;
                break;
            }
        }
        if relay is None and not setskill {
            targets = resolve_targets(world, bsp, target) if target else [];
            if target and not targets {
                continue;
            }
            relay = Signal(
                entities=[index],
                relay=True,
                once=kind == "trigger_once" or float(fields.get("wait", "0")) < 0.0,
                message="" if kind == "trigger_onlyregistered" else fields.get("message", ""),
                cue=authored_cue(bsp.game, kind, fields),
                delay=float(fields.get("delay", "0")) if bsp.game != "q3" else 0.0,
                armable=bsp.game == "q2" and flags & 4 != 0,
                armed=not (bsp.game == "q2" and flags & 4 != 0)
            );
            for destination in targets {
                relay +>:Targets:+> destination;
            }
            world +>:HasSignal:+> relay;
        }
        if relay is not None and not relay.enabled {
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
        if bsp.game == "q3" {
            interval += float(fields.get("random", "0"));
        }
        health = int(float(fields.get("health", "0"))) if bsp.game == "q1" else 0;
        trigger = TouchTrigger(
            model=model,
            volume=volume,
            interval=max(0.0, interval),
            once=secret
                or kind in ["trigger_once", "trigger_onlyregistered"]
                or interval < 0.0,
            signal=relay,
            touchable=health == 0 and not (bsp.game == "q1" and flags & 1 != 0),
            health=health,
            max_health=health,
            skill=int(float(fields.get("message", "1"))) if setskill else -1,
            monsters=bsp.game == "q2" and flags & 1 != 0,
            players=not (bsp.game == "q2" and flags & 2 != 0)
        );
        angle = float(fields.get("angle", "0"));
        if bsp.game in ["q1", "q2"] and angle != 0.0 {
            trigger.facing = Vec3(z=1.0)
                if angle == -1.0
                else (Vec3(z=-1.0) if angle == -2.0 else forward_from(math.radians(angle), 0.0));
        }
        # Q1 shootable triggers become solid boxes (trigger_multiple SOLID_BBOX).
        if health > 0 and collision is not None {
            for i in range(len(volumes.models)) {
                if volumes.models[i] == model {
                    collision.hulls.append(volumes.hulls[i]);
                    if collision.point_hulls {
                        collision.point_hulls.append(
                            volumes.point_hulls[i]
                                if i < len(volumes.point_hulls)
                                else volumes.hulls[i]
                        );
                    }
                    collision.offsets.append(volumes.offsets[i]);
                    collision.models.append(model);
                    if len(volumes.bounds) == len(volumes.hulls) {
                        collision.bounds.append(volumes.bounds[i]);
                    }
                    trigger.hulls.append(len(collision.hulls) - 1);
                    added = True;
                }
            }
        }
        if relay is not None {
            trigger +>:Activates:+> relay;
        }
        world +>:HasTrigger:+> trigger;
    }
    if added and collision is not None {
        collision.reindex();
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

"""trigger_monsterjump (Q1 trigger_monsterjump_touch, Q2 trigger_monsterjump_touch):
grounded walking monsters inside it leap along its angle at `speed` and `height`."""
edge HasMonsterJump: World --> MonsterJump {}
node MonsterJump {
    has volume: CollisionMap,
        push: Vec3 = Vec3(),
        height: float = 200.0;
}

walker MonsterJumpTick {
    has launched: int = 0,
        movers: list[Opponent] = [];

    can begin with World entry {
        self.movers = [
            actor
            for actor in [here->:HasOpponent:->][?:Opponent]
            if actor.health > 0
                and not actor.dormant
                and not actor.rule.inert
                and actor.rule.movement == "walk"
                and actor.grounded
        ];
        if self.movers {
            visit [here->:HasMonsterJump:->];
        }
    }

    can launch with MonsterJump entry {
        for actor in self.movers {
            origin = actor.pos.sub(Vec3(z=actor.eye_height));
            if not here.volume.trace(origin, origin, top_drop=0.0).start_solid {
                continue;
            }
            actor.velocity = Vec3(x=here.push.x, y=here.push.y, z=here.height);
            actor.grounded = False;
            self.launched += 1;
        }
    }
}

def load_monster_jumps(world: World, bsp: Bsp) {
    volumes: CollisionMap | None = None;
    for entity in bsp.entities {
        fields = entity.fields;
        if fields.get("classname", "") != "trigger_monsterjump"
            or not fields.get("model", "").startswith("*") {
            continue;
        }
        if volumes is None {
            volumes = build_collision(bsp, triggers=True)
                if bsp.game == "q1"
                else build_brush_collision(bsp, triggers=True);
        }
        volume = trigger_volume(volumes, int(fields["model"][1:]));
        if not volume.hulls {
            continue;
        }
        angle = float(fields.get("angle", "0"));
        heading = Vec3() if angle < 0.0 else forward_from(math.radians(angle), 0.0);
        speed = float(fields.get("speed", "0")) or 200.0;
        world +>:HasMonsterJump:+> MonsterJump(
            volume=volume,
            push=heading.scale(speed),
            height=float(fields.get("height", "0")) or 200.0
        );
    }
}
