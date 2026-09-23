"""Overkill deaths. A monster hit far enough past zero health bursts into a head
and gibs: Q1 ThrowHead/ThrowGib, Q2 ThrowHead/ThrowGib and Q3 CG_GibPlayer.
Each monster links to the models it breaks into through GibsInto edges; the
pieces are Gib entities that tumble, bounce, settle and fade on the world clock."""
import math;
import from .world { World, Entity, In, area_of, move_to_area }
import from .models { ModelResource, Visual, attach_model }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

"""How one kind of monster comes apart. `threshold` is the health at or below
which a death gibs; `head` and `pieces` are model paths; `style` picks the
original game's gib physics."""
obj GibRule {
    has threshold: int = 0,
        head: str = "",
        pieces: list[str] = [],
        sound: str = "",
        style: str = "q1";
}

edge GibsInto: Entity --> ModelResource {
    has count: int = 1,
        head: bool = False;
}

edge HasGib: World --> Gib {}
node Gib(Entity) {
    has velocity: Vec3 = Vec3(),
        spin: Vec3 = Vec3(),
        remaining: float = 15.0,
        lasting: bool = False,
        backoff: float = 1.5,
        damping: float = 1.0,
        stop_speed: float = 60.0,
        toss: bool = False,
        resting: bool = False,
        visual: Visual = Visual();
}

"""The seeded stream behind gib velocities, as random() and crandom()."""
obj GibDice {
    has seed: int = 1;

    def roll() -> float {
        self.seed = (self.seed * 48271) % 2147483647;
        return float(self.seed) / 2147483647.0;
    }

    def signed() -> float {
        return self.roll() * 2.0 - 1.0;
    }
}

"""Q1 VelocityForDamage and Q2 VelocityForDamage/ClipGibVelocity; Q3 throws
every gib at GIB_VELOCITY with a GIB_JUMP lift."""
def gib_velocity(style: str, overkill: int, dice: GibDice) -> Vec3 {
    if style == "q3" {
        return Vec3(x=dice.signed() * 250.0, y=dice.signed() * 250.0, z=250.0 + dice.signed() * 250.0);
    }
    if style == "q2" {
        v = Vec3(x=100.0 * dice.signed(), y=100.0 * dice.signed(), z=200.0 + 100.0 * dice.roll());
        v = v.scale(0.7 if overkill < 50 else 1.2);
        return Vec3(
            x=max(-300.0, min(300.0, v.x)),
            y=max(-300.0, min(300.0, v.y)),
            z=max(200.0, min(500.0, v.z))
        );
    }
    v = Vec3(x=100.0 * dice.signed(), y=100.0 * dice.signed(), z=200.0 + 100.0 * dice.roll());
    health = -overkill;
    if health > -50 {
        return v.scale(0.7);
    }
    if health > -200 {
        return v.scale(2.0);
    }
    return v.scale(10.0);
}

"""True when a death this far past zero health gibs the monster."""
def gibs_at(rule: GibRule | None, health: int) -> bool {
    return rule is not None and health <= rule.threshold;
}

"""Burst `victim` into its linked gib models at `origin` (the model origin).
Q1 heads stay where they land; every other piece fades after 10 to 20
seconds (Q3: 5 to 8)."""
def throw_gibs(
    world: World,
    victim: Entity,
    rule: GibRule,
    origin: Vec3,
    overkill: int,
    seed: int,
    base: Vec3 = Vec3()
) -> int {
    dice = GibDice(seed=max(1, seed % 2147483647));
    links = [edge victim->:GibsInto:->];
    models = [victim->:GibsInto:->][?:ModelResource];
    area = area_of(victim);
    thrown = 0;
    for index in range(min(len(links), len(models))) {
        link = links[index];
        for piece in range(link.count) {
            gib = Gib(pos=origin.add(Vec3(z=8.0 if link.head else 0.0)), yaw=victim.yaw);
            velocity = gib_velocity(rule.style, overkill, dice);
            if rule.style == "q2" {
                velocity = base.add(velocity.scale(0.5));
                gib.toss = True;
            }
            if rule.style == "q3" {
                gib.backoff = 2.0;
                gib.damping = 0.6;
                gib.stop_speed = 40.0;
                gib.remaining = 5.0 + dice.roll() * 3.0;
            } else {
                gib.remaining = 10.0 + dice.roll() * 10.0;
                if link.head {
                    gib.spin = Vec3(y=dice.signed() * 600.0);
                } else {
                    gib.spin = Vec3(x=dice.roll() * 600.0, y=dice.roll() * 600.0, z=dice.roll() * 600.0);
                }
            }
            gib.lasting = link.head and rule.style == "q1";
            gib.velocity = velocity;
            gib.visual = attach_model(gib, models[index]);
            if area is not None {
                move_to_area(gib, area);
            }
            world +>:HasGib:+> gib;
            thrown += 1;
        }
    }
    return thrown;
}

"""Gib flight: gravity, MOVETYPE_BOUNCE/TOSS clipping (Q3 reflection with a 0.6
bounce factor), landing and fading."""
walker GibTick {
    has collision: CollisionMap,
        dt: float,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        if self.dt > 0.0 {
            visit [here->:HasGib:->];
        }
    }

    can fly with Gib entry {
        world = self.world;
        if world is None {
            return;
        }
        if not here.lasting {
            here.remaining -= self.dt;
            if here.remaining <= 0.0 {
                for link in [edge here->:In:->] {
                    del link;
                }
                here.visual.visible = False;
                world del --> here;
                return;
            }
        }
        if here.resting {
            return;
        }
        here.visual.pitch += math.radians(here.spin.x * self.dt);
        here.yaw += math.radians(here.spin.y * self.dt);
        here.visual.roll += math.radians(here.spin.z * self.dt);
        here.velocity.z -= 800.0 * self.dt;
        finish = here.pos.add(here.velocity.scale(self.dt));
        trace = self.collision.trace_point(here.pos, finish);
        if trace.start_solid {
            here.resting = True;
            return;
        }
        here.pos = here.pos.lerp(finish, trace.fraction);
        if trace.fraction >= 1.0 {
            return;
        }
        normal = trace.normal;
        here.pos = here.pos.add(normal.scale(0.1));
        here.velocity = here.velocity.sub(
            normal.scale(here.velocity.dot(normal) * here.backoff)
        ).scale(here.damping);
        if normal.z > 0.7 and (here.toss or here.velocity.z < here.stop_speed) {
            here.velocity = Vec3();
            here.spin = Vec3();
            here.resting = True;
        }
    }
}
