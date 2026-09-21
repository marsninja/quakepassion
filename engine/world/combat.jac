"""Shared prototype hitscan combat and graph-driven opponents."""
import math;
import from .world { World, Player }
import from .damage { Damage }
import from .inventory { quantity, AdjustInventory }
import from .models { Visual }
import from ..physics.collision { CollisionMap }
import from ..physics.movement { MovePlayer }
import from ..math.vec3 { Vec3, forward_from }

edge HasOpponent: World --> Opponent {}
node Opponent(Player) {
    has modeled: bool = False,
        home: Vec3 = Vec3(),
        attack_wait: float = 0.7,
        respawn_wait: float = 0.0,
        arena: bool = False,
        visual: Visual = Visual(),
        animation: list[int] = [],
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
            victim.visual.visible = False;
            victim.respawn_wait = 3.0;
        }
    }
    return True;
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
        here.decision_wait -= self.dt;
        if here.decision_wait <= 0.0 {
            here.decision_wait = 0.1;
            here.pursuing = False;
            if distance < 1500.0 {
                sight = self.collision.trace_point(here.pos, self.player.pos);
                here.pursuing = not sight.start_solid and sight.fraction == 1.0;
                # Attack only with a fresh sight query, never cached visibility.
                if here.pursuing and here.attack_wait <= 0.0 {
                    self.player spawn Damage(amount=6 if here.arena else 4);
                    here.attack_wait = 0.8;
                }
            }
        }
        wish = Vec3();
        if here.pursuing and distance < 1500.0 {
            here.yaw = math.atan2(delta.y, delta.x);
            if distance > 180.0 {
                wish = Vec3(x=delta.x, y=delta.y).normalized();
            }
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
        if here.animation {
            here.animation_time += self.dt * (8.0 if wish.length() > 0.0 else 2.0);
            index = int(here.animation_time) % len(here.animation);
            here.visual.first = here.animation[index];
            here.visual.second = here.animation[(index + 1) % len(here.animation)];
            here.visual.blend = here.animation_time - float(int(here.animation_time));
        }
    }
}
