"""Shared prototype hitscan combat and graph-driven opponents."""
import math;
import from .world { World, Player }
import from .damage { Damage }
import from .inventory { quantity, AdjustInventory }
import from .models { Visual }
import from .signals { Signal, HasSignal, Fire }
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap }
import from ..physics.movement { MovePlayer }
import from ..math.vec3 { Vec3, forward_from }

edge HasOpponent: World --> Opponent {}
node Opponent(Player) {
    has activation: Signal = Signal(),
        modeled: bool = False,
        home: Vec3 = Vec3(),
        attack_wait: float = 0.7,
        attack_flash: float = 0.0,
        respawn_wait: float = 0.0,
        arena: bool = False,
        visual: Visual = Visual(),
        animation: list[int] = [],
        idle_animation: list[int] = [],
        attack_animation: list[int] = [],
        pose_name: str = "",
        last_seen: Vec3 = Vec3(),
        alert: float = 0.0,
        steering: Vec3 = Vec3(),
        animation_time: float = 0.0,
        decision_wait: float = 0.0,
        support_wait: float = 0.0,
        pursuing: bool = False;
}

obj CombatState {
    has cooldown: float = 0.0,
        flash: float = 0.0,
        hit_flash: float = 0.0,
        kills: int = 0,
        shots: int = 0,
        weapon: int = 1,
        target: Vec3 = Vec3();
}

# Finite ray versus actor box. A value of 1 means no hit before the endpoint.
def actor_fraction(start: Vec3, finish: Vec3, eye: Vec3, height: float) -> float {
    lo = eye.sub(Vec3(x=16.0, y=16.0, z=height + 24.0));
    hi = eye.add(Vec3(x=16.0, y=16.0, z=32.0 - height));
    origins = [start.x, start.y, start.z];
    deltas = [finish.x - start.x, finish.y - start.y, finish.z - start.z];
    mins = [lo.x, lo.y, lo.z];
    maxs = [hi.x, hi.y, hi.z];
    enter = 0.0;
    leave = 1.0;
    for axis in range(3) {
        if abs(deltas[axis]) < 0.000001 {
            if origins[axis] < mins[axis] or origins[axis] > maxs[axis] {
                return 1.0;
            }
        } else {
            a = (mins[axis] - origins[axis]) / deltas[axis];
            b = (maxs[axis] - origins[axis]) / deltas[axis];
            enter = max(enter, min(a, b));
            leave = min(leave, max(a, b));
            if enter > leave {
                return 1.0;
            }
        }
    }
    return enter;
}

walker Aim {
    has start: Vec3,
        finish: Vec3,
        height: float,
        fraction: float = 1.0,
        target: Opponent | None = None;

    can begin with World entry {
        visit [here->:HasOpponent:->];
    }

    can test_target with Opponent entry {
        if here.health <= 0 {
            return;
        }
        hit = actor_fraction(self.start, self.finish, here.pos, self.height);
        if hit < self.fraction {
            self.fraction = hit;
            self.target = here;
        }
    }
}

def fire_weapon(
    world: World, player: Player, collision: CollisionMap, state: CombatState
) -> bool {
    if player.health <= 0 or state.cooldown > 0.000001 {
        return False;
    }
    heavy = state.weapon == 2;
    if heavy and quantity(player.inventory, "shells") <= 0 {
        return False;
    }
    if heavy {
        player.inventory spawn AdjustInventory(kind="shells", amount=-1);
    }
    state.cooldown = 0.7 if heavy else 0.3;
    state.flash = 0.08;
    state.shots += 1;
    finish = player.pos.add(forward_from(player.yaw, player.pitch).scale(4096.0));
    wall = collision.trace_point(player.pos, finish);
    query = world spawn Aim(
        start=player.pos,
        finish=finish,
        height=collision.eye_height,
        fraction=wall.fraction
    );
    state.target = player.pos.lerp(finish, query.fraction);
    victim = query.target;
    if victim is not None {
        damage = victim spawn Damage(amount=50 if heavy else 15);
        state.hit_flash = 0.15;
        if damage.killed {
            state.kills += 1;
            victim.activation spawn Fire(inventory=player.inventory);
            victim.visual.visible = False;
            victim.respawn_wait = 3.0;
        }
    }
    return True;
}

def load_opponent_signals(world: World, bsp: Bsp) {
    for index in range(len(bsp.entities)) {
        if bsp.entities[index].fields.get("classname", "").startswith("monster_") {
            world +>:HasSignal:+> Signal(entities=[index]);
        }
    }
}

walker CombatTick {
    has player: Player,
        collision: CollisionMap,
        state: CombatState,
        dt: float,
        active: bool = True;

    can begin with World entry {
        self.state.cooldown = max(0.0, self.state.cooldown - self.dt);
        self.state.flash = max(0.0, self.state.flash - self.dt);
        self.state.hit_flash = max(0.0, self.state.hit_flash - self.dt);
        if self.active and self.player.health > 0 {
            visit [here->:HasOpponent:->];
        }
    }

    can think with Opponent entry {
        if here.health <= 0 {
            if not here.arena {
                return;
            }
            here.respawn_wait = max(0.0, here.respawn_wait - self.dt);
            if here.respawn_wait > 0.0
                or here.home.sub(self.player.pos).length() < 80.0 {
                return;
            }
            here.health = here.max_health;
            here.pos = here.home;
            here.velocity = Vec3();
            here.visual.visible = True;
            here.attack_wait = 1.0;
        }
        delta = self.player.pos.sub(here.pos);
        distance = delta.length();
        here.attack_wait = max(0.0, here.attack_wait - self.dt);
        here.attack_flash = max(0.0, here.attack_flash - self.dt);
        here.alert = max(0.0, here.alert - self.dt);
        here.decision_wait -= self.dt;
        if here.decision_wait <= 0.0 {
            here.decision_wait = 0.1;
            here.pursuing = False;
            if distance < 1500.0 {
                sight = self.collision.trace_point(here.pos, self.player.pos);
                here.pursuing = not sight.start_solid and sight.fraction == 1.0;
                if here.pursuing { here.last_seen = self.player.pos; here.alert = 8.0; }
                # Attack only with a fresh sight query, never cached visibility.
                if here.pursuing and here.attack_wait <= 0.0 {
                    self.player spawn Damage(amount=6 if here.arena else 4);
                    here.attack_wait = 0.8;
                    here.attack_flash = 0.25;
                }
            }
            here.steering = Vec3();
            goal = here.last_seen.sub(here.pos);
            if here.alert > 0.0 and goal.length() > (180.0 if here.pursuing else 24.0) {
                direction = Vec3(x=goal.x, y=goal.y).normalized();
                best = -1.0;
                for angle in [0.0, 0.785398, -0.785398, 1.570796, -1.570796] {
                    candidate = Vec3(x=direction.x * math.cos(angle) - direction.y * math.sin(angle),
                        y=direction.x * math.sin(angle) + direction.y * math.cos(angle));
                    probe = self.collision.trace(here.pos, here.pos.add(candidate.scale(48.0)));
                    score = probe.fraction + 0.15 * math.cos(angle);
                    if not probe.start_solid and probe.fraction > 0.3 and score > best {
                        best = score;
                        here.steering = candidate;
                    }
                }
            }
        }
        wish = here.steering;
        if here.alert > 0.0 {
            goal = here.last_seen.sub(here.pos);
            here.yaw = math.atan2(goal.y, goal.x);
        }
        here.support_wait -= self.dt;
        # Settled actors probe support at 20 Hz; motion and gravity remain 120 Hz.
        if not here.grounded
            or here.velocity.length() > 0.000001
            or wish.length() > 0.0
            or here.support_wait <= 0.0 {
            here spawn MovePlayer(collision=self.collision, wish=wish, dt=self.dt);
            here.support_wait = 0.05;
        }
        pose_name = "attack" if here.attack_flash > 0.0 else (
            "run" if wish.length() > 0.0 else "stand"
        );
        frames = here.attack_animation if pose_name == "attack" else (
            here.animation if pose_name == "run" else here.idle_animation
        );
        if not frames { frames = here.animation; }
        if pose_name != here.pose_name { here.animation_time = 0.0; here.pose_name = pose_name; }
        if frames {
            here.animation_time += self.dt * (8.0 if pose_name != "stand" else 2.0);
            index = int(here.animation_time) % len(frames);
            here.visual.first = frames[index];
            here.visual.second = frames[(index + 1) % len(frames)];
            here.visual.blend = here.animation_time - float(int(here.animation_time));
        }
    }
}
