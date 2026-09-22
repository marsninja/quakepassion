"""Q1's authored electrode encounter, driven by target and mover graphs."""
import math;
import from .world { World, Player }
import from .signals { Signal, HasSignal, Fire }
import from .combat { Opponent, HasOpponent, Projectile, HasProjectile, CombatState }
import from .doors { Door, HasDoor, DoorMember }
import from .models { ModelResource, UsesModel }
import from ..formats.bsp { Bsp }
import from ..math.vec3 { Vec3, forward_from, right_from }

edge HasLightning: World --> LightningEvent {}
edge Electrode: LightningEvent --> Door {}
node LightningEvent {
    has activation: Signal,
        remaining: float = 0.0;
}

def load_lightning(world: World, bsp: Bsp) {
    if bsp.game != "q1" {
        return;
    }
    for index in range(len(bsp.entities)) {
        if bsp.entities[index].fields.get("classname", "") == "event_lightning" {
            event = LightningEvent(activation=Signal(entities=[index]));
            world +>:HasLightning:+> event;
            world +>:HasSignal:+> event.activation;
        }
    }
}

def connect_electrodes(world: World, bsp: Bsp) {
    for event in [world->:HasLightning:->][?:LightningEvent] {
        for door in [world->:HasDoor:->][?:Door] {
            for index in door.activation.entities {
                if bsp.entities[index].fields.get("target", "") == "lightning" {
                    event +>:Electrode:+> door;
                    break;
                }
            }
        }
    }
}

def electrode_point(door: Door) -> Vec3 {
    point = door.bounds.center().add(door.rest).add(door.travel.scale(door.position));
    point.z = door.bounds.mins.z + door.rest.z + door.travel.z * door.position - 16.0;
    return point;
}

def boss_pose(enemy: Opponent) {
    phases = ["", "rise", "attack", "shocka", "shockb", "shockc", "death", ""];
    if enemy.boss_phase <= 0 or enemy.boss_phase >= 7 {
        return;
    }
    prefix = phases[enemy.boss_phase];
    index = int(enemy.boss_time * 10.0);
    if enemy.boss_phase == 4 {
        index %= 6;
    }
    for resource in [enemy.visual->:UsesModel:->][?:ModelResource] {
        frames = resource.model.surfaces[0].frames;
        selected = [
            i
            for i in range(len(frames))
            if frames[i].name.startswith(prefix)
        ];
        if selected {
            index = min(index, len(selected) - 1);
            enemy.visual.first = selected[index];
            enemy.visual.second = selected[min(index + 1, len(selected) - 1)];
            enemy.visual.blend = enemy.boss_time * 10.0
                - float(int(enemy.boss_time * 10.0));
        }
    }
}

walker ChthonTick {
    has player: Player,
        state: CombatState,
        dt: float,
        eye_height: float = 22.0,
        world: World | None = None;

    can begin with World entry {
        if self.dt <= 0.0 or self.player.health <= 0 {
            return;
        }
        self.world = here;
        visit [here->:HasLightning:->];
        visit [here->:HasOpponent:->];
    }

    can lightning with LightningEvent entry {
        doors = [here->:Electrode:->][?:Door];
        requested = here.activation.pending > 0;
        here.activation.pending = 0;
        if len(doors) != 2 or not here.activation.enabled {
            return;
        }
        if here.remaining > 0.0 {
            here.remaining = max(0.0, here.remaining - self.dt);
            for door in doors {
                if here.remaining == 0.0 {
                    door.state = "closing";
                } else {
                    door.remaining = max(door.remaining, here.remaining + self.dt);
                }
            }
            return;
        }
        if not requested
            or doors[0].state != doors[1].state
            or doors[0].state not in ["closed", "open"] {
            return;
        }
        here.remaining = 1.0;
        for door in doors {
            door.remaining = max(door.remaining, 1.0 + self.dt);
        }
        if doors[0].state != "open" or self.world is None {
            return;
        }
        for boss in [self.world->:HasOpponent:->][?:Opponent] {
            if boss.rule.script != "chthon" or boss.dormant or boss.health <= 0 {
                continue;
            }
            boss.health -= 1;
            boss.boss_phase = 3 if boss.health >= 2 else (4 if boss.health == 1 else 5);
            boss.boss_time = 0.0;
        }
    }

    can boss with Opponent entry {
        if here.rule.script != "chthon" or self.world is None {
            return;
        }
        if here.boss_phase == 0 {
            if here.activation.pending <= 0 {
                return;
            }
            here.activation.pending = 0;
            here.dormant = False;
            here.visual.visible = True;
            here.boss_phase = 1;
            here.boss_time = 0.0;
        }
        if here.boss_phase == 7 {
            return;
        }
        old_time = here.boss_time;
        here.boss_time += self.dt;
        delta = self.player.pos.sub(here.pos);
        if here.boss_phase in [1, 2] {
            here.yaw = math.atan2(delta.y, delta.x);
        }
        if here.boss_phase == 2 {
            for shot in [0.8, 1.9] {
                if old_time < shot and here.boss_time >= shot {
                    origin = here.pos.sub(Vec3(z=self.eye_height)).add(
                        forward_from(here.yaw, 0.0).scale(100.0)
                    ).add(
                        right_from(here.yaw).scale(100.0 if shot == 0.8 else -100.0)
                    ).add(
                        Vec3(z=200.0)
                    );
                    target = self.player.pos.sub(Vec3(z=self.eye_height));
                    self.world +>:HasProjectile:+> Projectile(
                        pos=origin,
                        velocity=target.sub(origin).normalized().scale(300.0),
                        damage=100,
                        splash=120,
                        radius=160.0,
                        hostile=True,
                        effect="q1_lavaball",
                        remaining=5.0
                    );
                }
            }
        }
        duration = 1.7
            if here.boss_phase == 1
            else (
                2.3 if here.boss_phase == 2 else (0.9 if here.boss_phase == 6 else 1.0)
            );
        if here.boss_time >= duration {
            here.boss_time = 0.0;
            if here.boss_phase == 5 {
                here.boss_phase = 6;
            } elif here.boss_phase == 6 {
                here.boss_phase = 7;
                here.visual.visible = False;
                self.state.kills += 1;
                here.activation spawn Fire(inventory=self.player.inventory);
            } else {
                here.boss_phase = 2;
            }
        }
        boss_pose(here);
    }
}
