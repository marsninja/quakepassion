"""Q1's authored electrode encounter (boss.qc), driven by target and mover
graphs. Chthon plays its QuakeC frame functions at 10 Hz: it rises, throws
lava balls while turning to face the player at its yaw speed, reels from
each lightning strike and dies after the last."""
import math;
import from .world { World, Player }
import from .signals { Signal, HasSignal, Fire }
import from .combat { Opponent, HasOpponent, Projectile, HasProjectile, CombatState, request_sound }
import from .doors { Door, HasDoor, DoorMember }
import from .models { ModelResource, UsesModel }
import from .particles { beam_trail, explode }
import from .speakers { Speaker, HasSpeaker }
import from ..formats.bsp { Bsp }
import from ..math.vec3 { Vec3 }
import from ..math.orientation { change_yaw }

edge HasLightning: World --> LightningEvent {}
edge Electrode: LightningEvent --> Door {}
"""event_lightning: `remaining` is lightning_end less the time now; the
event's own speaker plays misc/power.wav as each bolt starts."""
node LightningEvent {
    has activation: Signal,
        remaining: float = 0.0,
        beat: float = 0.0,
        speaker: Speaker | None = None;
}

# boss_phase values: the frame function families of boss.qc.
glob BOSS_DORMANT: int = 0;
glob BOSS_RISE: int = 1;
glob BOSS_MISSILE: int = 2;
glob BOSS_SHOCKA: int = 3;
glob BOSS_SHOCKB: int = 4;
glob BOSS_SHOCKC: int = 5;
glob BOSS_DEATH: int = 6;
glob BOSS_GONE: int = 7;
glob BOSS_IDLE: int = 8;

# boss_awake: yaw_speed 20, degrees a frame.
glob BOSS_YAW_SPEED: float = 20.0;

"""How many 0.1 s frames each family runs before it moves on."""
def boss_frames(phase: int) -> int {
    if phase == BOSS_RISE {
        return 17;
    }
    if phase == BOSS_MISSILE {
        return 23;
    }
    if phase == BOSS_IDLE {
        return 31;
    }
    # shocka1-10, shockb1-10, shockc1-10, death1-9 and death10.
    return 10;
}

"""The family a finished one hands on to (each frame's `next` think)."""
def boss_next(phase: int) -> int {
    if phase == BOSS_SHOCKC {
        return BOSS_DEATH;
    }
    if phase == BOSS_DEATH {
        return BOSS_GONE;
    }
    if phase == BOSS_IDLE {
        return BOSS_IDLE;
    }
    return BOSS_MISSILE;
}

def load_lightning(world: World, bsp: Bsp) {
    if bsp.game != "q1" {
        return;
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") == "event_lightning" {
            parts = fields.get("origin", "0 0 0").split();
            origin = Vec3();
            if len(parts) == 3 {
                origin = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            }
            speaker = Speaker(path="sound/misc/power.wav", origin=origin);
            world +>:HasSpeaker:+> speaker;
            event = LightningEvent(activation=Signal(entities=[index]), speaker=speaker);
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

"""lightning_fire's terminal: the electrode's middle (its model bounds, which
do not move with it) at 16 below its current bottom."""
def electrode_point(door: Door) -> Vec3 {
    point = door.bounds.center().add(door.rest);
    point.z = door.bounds.mins.z + door.rest.z + door.travel.z * door.position - 16.0;
    return point;
}

def boss_pose(enemy: Opponent) {
    phases = ["", "rise", "attack", "shocka", "shockb", "shockc", "death", "", "walk"];
    if enemy.boss_phase <= BOSS_DORMANT or enemy.boss_phase == BOSS_GONE {
        return;
    }
    prefix = phases[enemy.boss_phase];
    index = int(enemy.boss_time * 10.0);
    # boss_shockb7-10 play shockb1-4 again.
    if enemy.boss_phase == BOSS_SHOCKB {
        index %= 6;
    }
    for resource in [enemy.visual->:UsesModel:->][?:ModelResource] {
        frames = resource.model.surfaces[0].frames;
        selected = [
            i
            for i in range(len(frames))
            if frames[i].name.startswith(prefix)
                and frames[i].name[len(prefix):].isdigit()
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
        if self.dt <= 0.0 {
            return;
        }
        self.world = here;
        visit [here->:HasLightning:->];
        visit [here->:HasOpponent:->];
    }

    """lightning_use and lightning_fire."""
    can lightning with LightningEvent entry {
        doors = [here->:Electrode:->][?:Door];
        requested = here.activation.pending > 0;
        here.activation.pending = 0;
        if len(doors) != 2 or not here.activation.enabled {
            return;
        }
        if here.remaining > 0.0 {
            here.remaining = max(0.0, here.remaining - self.dt);
            here.beat = max(0.0, here.beat - self.dt);
            for door in doors {
                if here.remaining == 0.0 {
                    # Done here: the terminals go back up (door_go_down).
                    door.state = "closing";
                } else {
                    door.remaining = max(door.remaining, here.remaining + self.dt);
                }
            }
            if here.remaining > 0.0 and here.beat <= 0.0 {
                self.bolt(here, doors);
            }
        }
        # lightning_use: ignored only while a bolt has just begun
        # (lightning_end >= time + 1), and only with both electrodes at rest
        # at the same end.
        if not requested
            or here.remaining >= 1.0
            or doors[0].state != doors[1].state
            or doors[0].state not in ["closed", "open"] {
            return;
        }
        here.remaining = 1.0;
        for door in doors {
            door.remaining = max(door.remaining, 1.0 + self.dt);
        }
        speaker = here.speaker;
        if speaker is not None {
            speaker.requests += 1;
        }
        self.bolt(here, doors);
        if doors[0].state != "open" or self.world is None {
            return;
        }
        for boss in [self.world->:HasOpponent:->][?:Opponent] {
            if boss.rule.script != "chthon" or boss.dormant or boss.health <= 0 {
                continue;
            }
            request_sound(boss, "sound/boss1/pain.wav");
            boss.health -= 1;
            if boss.health >= 2 {
                self.enter(boss, BOSS_SHOCKA);
            } elif boss.health == 1 {
                self.enter(boss, BOSS_SHOCKB);
            } else {
                self.enter(boss, BOSS_SHOCKC);
            }
        }
    }

    """lightning_fire: a TE_LIGHTNING3 bolt between the terminals every 0.1 s,
    its far end drawn 100 units short for the length of the bolt model."""
    def bolt(event: LightningEvent, doors: list[Door]) {
        event.beat = 0.1;
        world = self.world;
        if world is None {
            return;
        }
        start = electrode_point(doors[0]);
        finish = electrode_point(doors[1]);
        finish = finish.sub(finish.sub(start).normalized().scale(100.0));
        beam_trail(world, start, finish, "q1_lightning3");
    }

    can boss with Opponent entry {
        if here.rule.script != "chthon" or self.world is None {
            return;
        }
        if here.boss_phase == BOSS_DORMANT {
            if here.activation.pending <= 0 {
                return;
            }
            # boss_awake.
            here.activation.pending = 0;
            here.dormant = False;
            here.visual.visible = True;
            here.health = 1 if here.skill == 0 else 3;
            here.max_health = here.health;
            explode(self.world, here.pos.sub(Vec3(z=self.eye_height)), "q1_lavasplash");
            self.enter(here, BOSS_RISE);
        }
        remaining = self.dt;
        while remaining > 0.0
            and here.boss_phase != BOSS_GONE
            and here.boss_phase != BOSS_DORMANT {
            reached = float(int(here.boss_time * 10.0 + 0.000001) + 1) * 0.1;
            step = reached - here.boss_time;
            if step > remaining + 0.000001 {
                here.boss_time += remaining;
                break;
            }
            remaining = max(0.0, remaining - step);
            here.boss_time = reached;
            frame = int(reached * 10.0 + 0.5);
            if frame >= boss_frames(here.boss_phase) {
                self.enter(here, boss_next(here.boss_phase));
            } else {
                self.frame(here, frame);
            }
        }
        boss_pose(here);
    }

    """Start a frame family at its first frame, running that frame's think."""
    def enter(boss: Opponent, phase: int) {
        boss.boss_phase = phase;
        boss.boss_time = 0.0;
        self.frame(boss, 0);
    }

    """One QuakeC frame function of boss.qc."""
    def frame(boss: Opponent, index: int) {
        phase = boss.boss_phase;
        world = self.world;
        if phase == BOSS_RISE {
            if index == 0 {
                request_sound(boss, "sound/boss1/out1.wav");
            } elif index == 1 {
                request_sound(boss, "sound/boss1/sight1.wav");
            }
        } elif phase == BOSS_MISSILE {
            if index == 8 {
                self.missile(boss, Vec3(x=100.0, y=100.0, z=200.0));
            } elif index == 19 {
                self.missile(boss, Vec3(x=100.0, y=-100.0, z=200.0));
            } else {
                self.face(boss);
            }
        } elif phase == BOSS_IDLE {
            # boss_idle1: back to throwing at a living enemy.
            if index == 0 and self.player.health > 0 {
                self.enter(boss, BOSS_MISSILE);
            } else {
                self.face(boss);
            }
        } elif phase == BOSS_DEATH {
            if index == 0 {
                request_sound(boss, "sound/boss1/death.wav");
            } elif index == 8 {
                request_sound(boss, "sound/boss1/out1.wav");
                if world is not None {
                    explode(world, boss.pos.sub(Vec3(z=self.eye_height)), "q1_lavasplash");
                }
            } elif index == 9 {
                # boss_death10: counted, its targets used, removed.
                boss.boss_phase = BOSS_GONE;
                boss.visual.visible = False;
                self.state.kills += 1;
                boss.activation spawn Fire(inventory=self.player.inventory);
            }
        }
    }

    """boss_face (ai_face): turn toward the enemy at the yaw speed."""
    def face(boss: Opponent) {
        toward = self.player.pos.sub(boss.pos);
        if abs(toward.x) < 0.000001 and abs(toward.y) < 0.000001 {
            return;
        }
        boss.yaw = change_yaw(boss.yaw, math.atan2(toward.y, toward.x), BOSS_YAW_SPEED);
    }

    """boss_missile: a lava ball from `offset` (forward, right, up) along
    makevectors(vectoangles(enemy - self)), whose inverted pitch mirrors the
    forward lift, aimed at the enemy or, above Normal skill, where its
    ground speed will carry it by the time the ball arrives."""
    def missile(boss: Opponent, offset: Vec3) {
        world = self.world;
        if world is None {
            return;
        }
        origin = boss.pos.sub(Vec3(z=boss.eye_height));
        enemy = self.player.pos.sub(Vec3(z=self.eye_height));
        toward = enemy.sub(origin);
        yaw = math.atan2(toward.y, toward.x);
        flat = math.sqrt(toward.x * toward.x + toward.y * toward.y);
        pitch = math.atan2(toward.z, flat);
        forward = Vec3(
            x=math.cos(pitch) * math.cos(yaw),
            y=math.cos(pitch) * math.sin(yaw),
            z=-math.sin(pitch)
        );
        right = Vec3(x=math.sin(yaw), y=-math.cos(yaw));
        start = origin.add(forward.scale(offset.x))
            .add(right.scale(offset.y))
            .add(Vec3(z=offset.z));
        aim = enemy;
        if boss.skill > 1 {
            lead = enemy.sub(start).length() / 300.0;
            aim = enemy.add(
                Vec3(x=self.player.velocity.x, y=self.player.velocity.y).scale(lead)
            );
        }
        # T_MissileTouch: 100 + random() * 20 on a direct hit, 120 splash.
        boss.shot_random = (boss.shot_random * 48271) % 2147483647;
        world +>:HasProjectile:+> Projectile(
            pos=start,
            velocity=aim.sub(start).normalized().scale(300.0),
            damage=100 + int(float(boss.shot_random) / 2147483647.0 * 20.0),
            splash=120,
            radius=160.0,
            hostile=True,
            effect="q1_lavaball",
            owner=boss,
            remaining=6.0
        );
        request_sound(boss, "sound/boss1/throw.wav");
        # boss_missile: with its enemy dead it idles.
        if self.player.health <= 0 {
            self.enter(boss, BOSS_IDLE);
        }
    }
}
