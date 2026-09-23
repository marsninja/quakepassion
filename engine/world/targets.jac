"""Q2 scripted target entities (g_target.c) as activatable graph nodes.

target_explosion deals `dmg` radius damage (radius dmg+40) with a rocket-style
blast; target_splash sprays particles and optionally hurts; target_earthquake
jolts grounded actors for `count` seconds; target_laser is a toggled damaging
beam; target_help updates the help computer's objectives."""
import math;
import from .world { World, Player }
import from .combat {
    Opponent,
    HasOpponent,
    CombatState,
    WeaponImpact,
    blast_actors,
    damage_opponent,
    actor_fraction
}
import from .damage { Damage }
import from .particles { impact_spray, beam_trail }
import from .speakers { Speaker, HasSpeaker }
import from .signals { Signal, HasSignal }
import from .shooters { move_direction }
import from .powerups { Powerup, Empowered }
import from .pickups { Pickup, HasPickup, PickupTick }
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

edge HasTarget: World --> TargetEvent {}
node TargetEvent {
    has kind: str,
        origin: Vec3 = Vec3(),
        direction: Vec3 = Vec3(x=1.0),
        damage: int = 0,
        count: int = 0,
        speed: float = 200.0,
        message: str = "",
        primary: bool = False,
        on: bool = False,
        color: str = "laser_red",
        remaining: float = 0.0,
        clock: float = 0.0,
        random_state: int = 1,
        speaker: Speaker | None = None,
        gifts: list[int] = [],
        activation: Signal = Signal();

    def random() -> float {
        self.random_state = (self.random_state * 48271) % 2147483647;
        return float(self.random_state) / 2147483647.0 * 2.0 - 1.0;
    }
}

"""The help computer's current objectives (game.helpmessage1/2)."""
edge HasHelp: World --> HelpComputer {}
node HelpComputer {
    has primary: str = "",
        secondary: str = "",
        changed: int = 0;
}

def help_for(world: World) -> HelpComputer {
    found = [world->:HasHelp:->][?:HelpComputer];
    if found {
        return found[0];
    }
    computer = HelpComputer();
    world +>:HasHelp:+> computer;
    return computer;
}

walker TargetTick {
    has player: Player,
        collision: CollisionMap,
        state: CombatState,
        dt: float,
        world: World | None = None,
        message: str = "",
        cues: list[str] = [];

    can begin with World entry {
        if self.dt > 0.0 {
            self.world = here;
            visit [here->:HasTarget:->];
        }
    }

    can act with TargetEvent entry {
        world = self.world;
        if world is None or here.activation.killed {
            return;
        }
        uses = here.activation.pending;
        here.activation.pending = 0;
        speaker = here.speaker;
        for i in range(uses) {
            if here.kind in ["laser", "light"] {
                here.on = not here.on;
                continue;
            }
            if here.kind == "earthquake" {
                here.remaining = float(here.count);
                here.clock = 0.0;
            }
            # g_target.c Use_target_remove_powerups / Use_Target_Print.
            if here.kind == "remove_powerups" {
                for power in [self.player->:Empowered:->][?:Powerup] {
                    if power.kind != "vitality" {
                        self.player del --> power;
                    }
                }
            }
            # g_target.c Use_Target_Give: touch every targeted item for the user.
            if here.kind == "give" {
                gifts = [
                    pickup
                    for pickup in [world->:HasPickup:->][?:Pickup]
                    if any([index in pickup.activation.entities for index in here.gifts])
                ];
                if gifts {
                    handed = world spawn PickupTick(
                        player=self.player,
                        start=self.player.pos,
                        finish=self.player.pos,
                        dt=0.01,
                        advance_time=False,
                        targets=gifts,
                        selected_only=True,
                        forced=True
                    );
                    self.cues.extend(handed.sounds);
                    for gift in gifts {
                        gift.waiting_for_use = True;
                        gift.active = False;
                        gift.visual.visible = False;
                    }
                }
            }
            if here.kind == "print" and here.message {
                self.message = here.message;
            }
            if here.kind == "help" {
                computer = help_for(world);
                if here.primary {
                    computer.primary = here.message;
                } else {
                    computer.secondary = here.message;
                }
                computer.changed += 1;
                self.message = "Help computer updated (F1)";
                self.cues.append("sound/misc/pc_up.wav");
            }
            if here.kind == "explosion" {
                blast_actors(
                    world,
                    here.origin,
                    here.damage,
                    float(here.damage + 40),
                    True,
                    self.player,
                    self.collision,
                    self.state
                );
                self.state.impacts.append(
                    WeaponImpact(
                        origin=here.origin,
                        splash=here.damage,
                        radius=float(here.damage + 40)
                    )
                );
                for j in range(3) {
                    impact_spray(world, here.origin, Vec3(z=1.0));
                }
            }
            if here.kind == "splash" {
                for j in range(max(1, here.count // 8)) {
                    impact_spray(world, here.origin, here.direction);
                }
                if here.damage > 0 {
                    blast_actors(
                        world,
                        here.origin,
                        here.damage,
                        float(here.damage + 40),
                        True,
                        self.player,
                        self.collision,
                        self.state
                    );
                }
            }
            if speaker is not None and here.kind != "earthquake" {
                speaker.requests += 1;
            }
        }
        if here.kind == "earthquake" and here.remaining > 0.0 {
            self.quake(here);
        }
        if here.kind == "laser" and here.on {
            self.laser(here, world);
        }
    }

    # g_target.c target_earthquake_think: grounded actors get random shoves.
    def quake(event: TargetEvent) {
        event.remaining = max(0.0, event.remaining - self.dt);
        speaker = event.speaker;
        if speaker is not None {
            speaker.playing = event.remaining > 0.0;
        }
        event.clock -= self.dt;
        if event.clock > 0.0 {
            return;
        }
        event.clock = 0.1;
        if self.player.grounded and self.player.health > 0 {
            self.player.velocity = self.player.velocity.add(
                Vec3(
                    x=event.random() * 150.0,
                    y=event.random() * 150.0,
                    z=event.speed * (100.0 / 200.0)
                )
            );
            self.player.grounded = False;
        }
    }

    # target_laser_think: trace the beam each frame, hurting whatever it meets.
    def laser(event: TargetEvent, world: World) {
        finish = event.origin.add(event.direction.scale(2048.0));
        wall = self.collision.trace_point(event.origin, finish);
        reach = wall.fraction;
        victim: Player | None = None;
        hit = actor_fraction(
            event.origin, finish, self.player.pos, self.collision.eye_height, self.collision.top_drop
        );
        if self.player.health > 0 and hit < reach {
            reach = hit;
            victim = self.player;
        }
        for enemy in [world->:HasOpponent:->][?:Opponent] {
            if enemy.health <= 0 or enemy.dormant {
                continue;
            }
            touch = actor_fraction(event.origin, finish, enemy.pos, enemy.eye_height);
            if touch < reach {
                reach = touch;
                victim = enemy;
            }
        }
        event.clock -= self.dt;
        if event.clock <= 0.0 {
            event.clock = 0.1;
            beam_trail(world, event.origin, event.origin.lerp(finish, reach), event.color);
            target = victim;
            if target is not None and event.damage > 0 {
                if isinstance(target, Opponent) {
                    damage_opponent(target, event.damage);
                } else {
                    target spawn Damage(amount=event.damage, source=event.origin);
                }
            }
        }
    }
}

def target_origin(fields: dict[str, str]) -> Vec3 {
    parts = fields.get("origin", "0 0 0").split();
    if len(parts) != 3 {
        raise ValueError("Invalid target origin");
    }
    return Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
}

def load_targets(world: World, bsp: Bsp) {
    if bsp.game not in ["q1", "q2", "q3"] {
        return;
    }
    origins: dict[str, Vec3] = {};
    for entity in bsp.entities {
        name = entity.fields.get("targetname", "");
        if name and "origin" in entity.fields {
            origins[name] = target_origin(entity.fields);
        }
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        kind = fields.get("classname", "");
        q2_kinds = [
            "target_explosion",
            "target_splash",
            "target_earthquake",
            "target_laser",
            "target_help"
        ];
        q3_kinds = ["target_remove_powerups", "target_print", "target_give"];
        # Q1/Q2 named lights are switches (light_use: START_OFF 1 toggles style).
        toggled = bsp.game in ["q1", "q2"]
            and kind.startswith("light")
            and bool(fields.get("targetname", ""));
        if toggled {
            lamp = TargetEvent(
                kind="light",
                origin=target_origin(fields),
                on=int(fields.get("spawnflags", "0")) & 1 == 0,
                count=int(float(fields.get("style", "0"))),
                activation=Signal(entities=[index])
            );
            world +>:HasTarget:+> lamp;
            world +>:HasSignal:+> lamp.activation;
            continue;
        }
        if bsp.game == "q1"
            or kind not in (q2_kinds if bsp.game == "q2" else q3_kinds) {
            continue;
        }
        flags = int(fields.get("spawnflags", "0"));
        event = TargetEvent(
            kind=kind[7:],
            origin=target_origin(fields),
            direction=move_direction(fields),
            damage=int(float(fields.get("dmg", "0"))),
            count=int(float(fields.get("count", "0"))),
            speed=float(fields.get("speed", "0")) or 200.0,
            message=fields.get("message", ""),
            primary=flags & 1 != 0,
            random_state=1 + index * 7919,
            activation=Signal(entities=[index])
        );
        if event.kind == "give" {
            target = fields.get("target", "");
            event.gifts = [
                other
                for other in range(len(bsp.entities))
                if target and bsp.entities[other].fields.get("targetname", "") == target
            ];
        }
        sound = "";
        looping = False;
        if event.kind == "explosion" {
            sound = "sound/weapons/rocklx1a.wav";
        } elif event.kind == "splash" {
            event.count = event.count or 32;
        } elif event.kind == "earthquake" {
            event.count = event.count or 5;
            sound = "sound/world/quake.wav";
            looping = True;
        } elif event.kind == "laser" {
            # target_laser_start: START_ON 1, colours 2..32, default 1 damage.
            event.on = flags & 1 != 0;
            event.damage = event.damage or 1;
            event.color = "laser_red";
            for pair in [(4, "laser_green"), (8, "laser_blue"), (16, "laser_yellow"), (32, "laser_orange")] {
                if flags & pair[0] {
                    event.color = pair[1];
                }
            }
            target = fields.get("target", "");
            if target and target in origins {
                event.direction = origins[target].sub(event.origin).normalized();
            }
        }
        if sound {
            speaker = Speaker(path=sound, origin=event.origin, looping=looping);
            world +>:HasSpeaker:+> speaker;
            event.speaker = speaker;
        }
        world +>:HasTarget:+> event;
        world +>:HasSignal:+> event.activation;
    }
}
