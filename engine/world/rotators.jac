"""Continuously moving brush models: Q2/Q3 func_rotating, Q3 func_bobbing and
func_pendulum. Each is a `Rotator` node whose pose is a function of its own
clock, so saves only need that clock and the on/off state.

Poses follow the originals: func_rotating turns at `speed` degrees a second
(g_func.c SP_func_rotating), bobbing and pendulum motion are TR_SINE
trajectories (g_mover.c SP_func_bobbing / SP_func_pendulum). Riders and what
the mover swings into are carried round its origin in their own boxes (SV_Push,
G_MoverPush, engine/world/pusher.jac). A blocked Q2 func_rotating hurts the
obstacle by `dmg` and waits, a Q3 one only waits, and bobbing and pendulum
movers kill what they meet and never stop."""
import math;
import from .world { World, Player }
import from .combat { Opponent, HasOpponent, damage_opponent }
import from .damage { Damage }
import from .signals { Signal, HasSignal }
import from ..formats.bsp { Bsp, model_bounds, mover_origin }
import from ..physics.collision { CollisionMap, Trace, hull_sweep }
import from .pusher { Pushable, HullStep, GatherPushables, push_move }
import from ..math.vec3 { Vec3 }
import from ..math.orientation { Basis, quake_basis }
import from ..math.aabb { AABB }

edge HasRotator: World --> Rotator {}
node Rotator {
    has model: int,
        kind: str = "spin",
        faces: list[int] = [],
        hulls: list[int] = [],
        origins: list[Vec3] = [],
        pivot: Vec3 = Vec3(),
        axis: Vec3 = Vec3(y=1.0),
        speed: float = 100.0,
        height: float = 0.0,
        period: float = 1.0,
        phase: float = 0.0,
        active: bool = True,
        toggle: bool = False,
        damage: int = 2,
        touch_pain: bool = False,
        clock: float = 0.0,
        crush_wait: float = 0.0,
        activation: Signal = Signal();

    """Translation and orientation at time `t` on this mover's clock."""
    def pose(t: float) -> list[Vec3] {
        if self.kind == "bob" {
            wave = math.sin(2.0 * math.pi * (t / self.period + self.phase));
            return [self.axis.scale(wave * self.height), Vec3()];
        }
        if self.kind == "pendulum" {
            wave = math.sin(2.0 * math.pi * (t / self.period + self.phase));
            return [Vec3(), self.axis.scale(wave * self.speed)];
        }
        return [Vec3(), self.axis.scale((self.speed * t) % 360.0)];
    }
}

def turn_for(angles: Vec3) -> Basis | None {
    if angles.length() == 0.0 {
        return None;
    }
    return quake_basis(angles);
}

def place(mover: Rotator, t: float, bsp: Bsp, collision: CollisionMap) {
    parts = mover.pose(t);
    turn = turn_for(parts[1]);
    for face in mover.faces {
        bsp.faces[face].motion = parts[0];
        bsp.faces[face].turn = turn;
        bsp.faces[face].pivot = mover.pivot;
    }
    for j in range(len(mover.hulls)) {
        collision.set_offset(mover.hulls[j], mover.origins[j].add(parts[0]));
        collision.set_turn(mover.hulls[j], turn);
    }
}

def touching(mover: Rotator, collision: CollisionMap, origin: Vec3, t: float, top_drop: float) -> bool {
    parts = mover.pose(t);
    turn = turn_for(parts[1]);
    for j in range(len(mover.hulls)) {
        if not collision.reaches(mover.hulls[j], origin, 2.0) {
            continue;
        }
        for delta in [
            Vec3(x=1.0),
            Vec3(x=-1.0),
            Vec3(y=1.0),
            Vec3(y=-1.0),
            Vec3(z=1.0),
            Vec3(z=-1.0)
        ] {
            hit = hull_sweep(
                collision.hulls[mover.hulls[j]],
                origin,
                origin.add(delta),
                mover.origins[j].add(parts[0]),
                top_drop,
                False,
                turn
            );
            if hit.start_solid or hit.fraction < 1.0 {
                return True;
            }
        }
    }
    return False;
}

"""The turn of a pose about the vertical, in degrees, from `a` to `b`, the
short way round (SV_Push's amove[YAW])."""
def yaw_step(a: Vec3, b: Vec3) -> float {
    delta = b.y - a.y;
    while delta > 180.0 {
        delta -= 360.0;
    }
    while delta < -180.0 {
        delta += 360.0;
    }
    return delta;
}

walker RotatorTick {
    has bsp: Bsp,
        collision: CollisionMap,
        dt: float,
        player: Player | None = None,
        world: World | None = None,
        bodies: list[Pushable] = [];

    can start with World entry {
        if self.dt <= 0.0 {
            return;
        }
        self.world = here;
        movers = [here->:HasRotator:->][?:Rotator];
        if movers {
            found = here spawn GatherPushables(
                collision=self.collision, game=self.bsp.game, player=self.player
            );
            self.bodies = found.bodies;
        }
        visit movers;
    }

    can advance with Rotator entry {
        here.crush_wait = max(0.0, here.crush_wait - self.dt);
        if here.activation.killed {
            return;
        }
        if here.activation.pending > 0 {
            if here.toggle and here.activation.pending % 2 != 0 {
                here.active = not here.active;
            }
            here.activation.pending = 0;
        }
        if not here.active {
            return;
        }
        after = here.clock + self.dt;
        before_pose = here.pose(here.clock);
        after_pose = here.pose(after);
        steps: list[HullStep] = [];
        for j in range(len(here.hulls)) {
            steps.append(
                HullStep(
                    index=here.hulls[j],
                    offset_from=here.origins[j].add(before_pose[0]),
                    offset_to=here.origins[j].add(after_pose[0]),
                    turn_from=turn_for(before_pose[1]),
                    turn_to=turn_for(after_pose[1]),
                    yaw=yaw_step(before_pose[1], after_pose[1])
                )
            );
        }
        bodies = list(self.bodies);
        obstacle = push_move(self.collision, steps, bodies, self.bsp.game);
        # G_MoverPush: bobbing and pendulum movers (TR_SINE) kill what they
        # meet and are never blocked.
        while obstacle is not None and here.kind in ["bob", "pendulum"] {
            victim = obstacle.entity;
            if isinstance(victim, Player) {
                self.hurt(victim, 99999);
            }
            bodies = [body for body in bodies if body is not obstacle];
            obstacle = push_move(self.collision, steps, bodies, self.bsp.game);
        }
        if obstacle is not None {
            # Q2 rotating_blocked hurts what stops it; Q3's func_rotating has
            # no blocked function and only waits.
            victim = obstacle.entity;
            if self.bsp.game == "q2" and isinstance(victim, Player) {
                self.crush(here, victim);
            }
            return;
        }
        here.clock = after;
        place(here, here.clock, self.bsp, self.collision);
        # Q2 TOUCH_PAIN: any contact with a turning blade hurts.
        if here.touch_pain and self.player is not None and self.player.health > 0 {
            origin = self.player.pos.sub(Vec3(z=self.collision.eye_height));
            if touching(here, self.collision, origin, here.clock, self.collision.top_drop) {
                self.crush(here, self.player);
            }
        }
    }

    def crush(mover: Rotator, victim: Player) {
        if mover.damage <= 0 or mover.crush_wait > 0.0 {
            return;
        }
        mover.crush_wait = 0.1;
        self.hurt(victim, mover.damage);
    }

    def hurt(victim: Player, amount: int) {
        if victim.health <= 0 {
            return;
        }
        if isinstance(victim, Opponent) {
            damage_opponent(victim, amount, means="crush");
        } else {
            victim spawn Damage(amount=amount, means="crush");
        }
    }
}

def load_rotators(world: World, bsp: Bsp, collision: CollisionMap) {
    if bsp.game not in ["q2", "q3"] {
        return;
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        kind = fields.get("classname", "");
        if kind not in ["func_rotating", "func_bobbing", "func_pendulum"] {
            continue;
        }
        if kind != "func_rotating" and bsp.game != "q3" {
            continue;
        }
        name = fields.get("model", "");
        if not name.startswith("*") {
            continue;
        }
        model = int(name[1:]);
        if model <= 0 or model >= len(bsp.models) {
            raise ValueError("Invalid mover model");
        }
        flags = int(fields.get("spawnflags", "0"));
        mover = Rotator(
            model=model,
            pivot=mover_origin(fields),
            damage=int(float(fields.get("dmg", "2"))),
            activation=Signal(entities=[index])
        );
        if kind == "func_rotating" {
            # Default yaw; X_AXIS (4) rolls, Y_AXIS (8) pitches; REVERSE (2) in Q2.
            mover.axis = Vec3(z=1.0) if flags & 4 else (Vec3(x=1.0) if flags & 8 else Vec3(y=1.0));
            mover.speed = float(fields.get("speed", "0")) or 100.0;
            if bsp.game == "q2" {
                if flags & 2 {
                    mover.axis = mover.axis.scale(-1.0);
                }
                mover.active = flags & 1 != 0;
                mover.toggle = True;
                mover.touch_pain = flags & 16 != 0;
            }
        } elif kind == "func_bobbing" {
            # X_AXIS (1) and Y_AXIS (2); the default bobs vertically.
            mover.kind = "bob";
            mover.axis = Vec3(x=1.0) if flags & 1 else (Vec3(y=1.0) if flags & 2 else Vec3(z=1.0));
            mover.height = float(fields.get("height", "32"));
            mover.period = float(fields.get("speed", "4")) or 4.0;
            mover.phase = float(fields.get("phase", "0"));
        } else {
            mover.kind = "pendulum";
            mover.axis = Vec3(z=1.0);
            mover.speed = float(fields.get("speed", "30"));
            mover.phase = float(fields.get("phase", "0"));
            # SP_func_pendulum: fabs(r.mins[2]), at least 8. A model with an
            # origin brush stores its bounds relative to that origin.
            length = max(8.0, abs(model_bounds(bsp, model).mins.z));
            frequency = 1.0 / (math.pi * 2.0) * math.sqrt(800.0 / (3.0 * length));
            mover.period = 1.0 / frequency;
        }
        record = bsp.models[model];
        mover.faces = list(range(record.first_face, record.first_face + record.face_count));
        for i in range(len(collision.models)) {
            if collision.models[i] == model {
                mover.hulls.append(i);
                mover.origins.append(collision.offsets[i]);
                if mover.kind == "bob" {
                    extent = mover.axis.scale(abs(mover.height));
                    reach = Vec3(x=abs(extent.x), y=abs(extent.y), z=abs(extent.z));
                    box = collision.bounds[i];
                    collision.bounds[i] = AABB(mins=box.mins.sub(reach), maxs=box.maxs.add(reach));
                } else {
                    collision.allow_rotation(i);
                }
            }
        }
        if not mover.faces and not mover.hulls {
            continue;
        }
        for face in mover.faces {
            bsp.faces[face].moving_light = True;
        }
        world +>:HasRotator:+> mover;
        world +>:HasSignal:+> mover.activation;
        place(mover, 0.0, bsp, collision);
    }
    collision.reindex();
}
