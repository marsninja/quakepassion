"""Map traps that launch world-owned projectiles.

Q1 trap_spikeshooter fires when used and trap_shooter repeats every `wait`
(misc.qc): spikes at 500 u/s for 9 damage, superspikes 18, enforcer lasers at
600 u/s for 15. Q1 misc_fireball lobs lava balls (20 damage) at random
intervals up to five seconds. Q3 shooter_grenade/rocket/plasma fire when used,
with the `random` spread of g_misc.c Use_Shooter."""
import math;
import from .world { World }
import from .combat { Projectile, HasProjectile }
import from .speakers { Speaker, HasSpeaker }
import from .signals { Signal, HasSignal }
import from ..formats.bsp { Bsp }
import from ..math.vec3 { Vec3, forward_from, right_from }

edge HasShooter: World --> Shooter {}
node Shooter {
    has origin: Vec3,
        direction: Vec3 = Vec3(x=1.0),
        kind: str = "spike",
        interval: float = 0.0,
        clock: float = 0.0,
        speed: float = 1000.0,
        spread: float = 0.0,
        damage: int = 15,
        random_state: int = 1,
        speaker: Speaker | None = None,
        activation: Signal = Signal();

    def random() -> float {
        self.random_state = (self.random_state * 48271) % 2147483647;
        return float(self.random_state) / 2147483647.0;
    }
}

def launch(shooter: Shooter) -> Projectile {
    kind = shooter.kind;
    if kind == "fireball" {
        return Projectile(
            pos=shooter.origin,
            velocity=Vec3(
                x=shooter.random() * 100.0 - 50.0,
                y=shooter.random() * 100.0 - 50.0,
                z=shooter.speed + shooter.random() * 200.0
            ),
            damage=20,
            gravity=True,
            remaining=5.0,
            effect="q1_lavaball",
            hostile=True,
            trap=True
        );
    }
    direction = shooter.direction;
    if shooter.spread > 0.0 {
        side = right_from(math.atan2(direction.y, direction.x));
        up = side.cross(direction).normalized();
        deflect = math.sin(math.radians(shooter.spread));
        direction = direction.add(side.scale((shooter.random() * 2.0 - 1.0) * deflect)).add(
            up.scale((shooter.random() * 2.0 - 1.0) * deflect)
        ).normalized();
    }
    if kind == "laser" {
        return Projectile(pos=shooter.origin, velocity=direction.scale(600.0), damage=15, effect="q1_laser", hostile=True, trap=True);
    }
    if kind == "superspike" {
        return Projectile(pos=shooter.origin, velocity=direction.scale(500.0), damage=18, effect="q1_supernail", hostile=True, trap=True);
    }
    if kind == "grenade" {
        return Projectile(pos=shooter.origin, velocity=direction.scale(700.0).add(Vec3(z=200.0)), damage=100, splash=100, radius=150.0, gravity=True, remaining=2.5, effect="q3_grenade", hostile=True, trap=True);
    }
    if kind == "rocket" {
        return Projectile(pos=shooter.origin, velocity=direction.scale(900.0), damage=100, splash=100, radius=120.0, effect="q3_rocket", hostile=True, trap=True);
    }
    if kind == "blaster" {
        return Projectile(pos=shooter.origin, velocity=direction.scale(shooter.speed), damage=shooter.damage, effect="q2_bolt", hostile=True, trap=True);
    }
    if kind == "plasma" {
        return Projectile(pos=shooter.origin, velocity=direction.scale(2000.0), damage=20, splash=15, radius=20.0, effect="q3_plasma", hostile=True, trap=True);
    }
    return Projectile(pos=shooter.origin, velocity=direction.scale(500.0), damage=9, effect="q1_nail", hostile=True, trap=True);
}

walker ShooterTick {
    has dt: float,
        world: World | None = None,
        fired: int = 0;

    can begin with World entry {
        if self.dt > 0.0 {
            self.world = here;
            visit [here->:HasShooter:->];
        }
    }

    can trigger with Shooter entry {
        if here.activation.killed {
            return;
        }
        shots = here.activation.pending;
        here.activation.pending = 0;
        if here.interval > 0.0 {
            here.clock -= self.dt;
            while here.clock <= 0.0 {
                shots += 1;
                here.clock += here.interval
                    if here.kind != "fireball"
                    else max(0.1, here.random() * here.interval);
            }
        }
        world = self.world;
        if world is None {
            return;
        }
        for i in range(min(shots, 4)) {
            world +>:HasProjectile:+> launch(here);
            self.fired += 1;
            speaker = here.speaker;
            if speaker is not None {
                speaker.requests += 1;
            }
        }
    }
}

"""SetMovedir: angle -1 is up, -2 is down, otherwise `mangle` or `angle`."""
def move_direction(fields: dict[str, str]) -> Vec3 {
    if "mangle" in fields {
        parts = fields["mangle"].split();
        if len(parts) == 3 {
            return forward_from(
                math.radians(float(parts[1])), -math.radians(float(parts[0]))
            );
        }
    }
    if "angles" in fields {
        parts = fields["angles"].split();
        if len(parts) == 3 {
            return forward_from(
                math.radians(float(parts[1])), -math.radians(float(parts[0]))
            );
        }
    }
    angle = float(fields.get("angle", "0"));
    if angle == -1.0 {
        return Vec3(z=1.0);
    }
    if angle == -2.0 {
        return Vec3(z=-1.0);
    }
    return forward_from(math.radians(angle), 0.0);
}

def load_shooters(world: World, bsp: Bsp) {
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        kind = fields.get("classname", "");
        game = fields.get("asset_game", bsp.game);
        parts = fields.get("origin", "0 0 0").split();
        if len(parts) != 3 {
            continue;
        }
        origin = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
        flags = int(fields.get("spawnflags", "0"));
        shooter: Shooter | None = None;
        sound = "";
        if game == "q1" and kind in ["trap_spikeshooter", "trap_shooter"] {
            style = "laser" if flags & 2 else ("superspike" if flags & 1 else "spike");
            shooter = Shooter(origin=origin, direction=move_direction(fields), kind=style);
            sound = "sound/enforcer/enfire.wav" if style == "laser" else "sound/weapons/spike2.wav";
            if kind == "trap_shooter" {
                shooter.interval = float(fields.get("wait", "0")) or 1.0;
                shooter.clock = shooter.interval + float(fields.get("nextthink", "0"));
            }
        } elif game == "q1" and kind == "misc_fireball" {
            shooter = Shooter(
                origin=origin,
                kind="fireball",
                interval=5.0,
                speed=float(fields.get("speed", "0")) or 1000.0
            );
        } elif game == "q2" and kind == "target_blaster" {
            # g_target.c SP_target_blaster: 1000 u/s, 15 damage by default.
            shooter = Shooter(
                origin=origin,
                direction=move_direction(fields),
                kind="blaster",
                speed=float(fields.get("speed", "0")) or 1000.0,
                damage=int(float(fields.get("dmg", "0"))) or 15
            );
            sound = "sound/weapons/laser2.wav";
        } elif game == "q3" and kind in ["shooter_grenade", "shooter_rocket", "shooter_plasma"] {
            shooter = Shooter(
                origin=origin,
                direction=move_direction(fields),
                kind=kind[8:],
                spread=float(fields.get("random", "0"))
            );
            sound = "sound/weapons/" + (
                "grenade/grenlf1a.wav"
                    if kind == "shooter_grenade"
                    else ("rocket/rocklf1a.wav" if kind == "shooter_rocket" else "plasma/hyprbf1a.wav")
            );
        }
        if shooter is None {
            continue;
        }
        shooter.random_state = 1 + index * 7919;
        if shooter.kind == "fireball" {
            shooter.clock = shooter.random() * 5.0;
        }
        shooter.activation = Signal(entities=[index]);
        if sound {
            speaker = Speaker(path=sound, origin=origin);
            world +>:HasSpeaker:+> speaker;
            shooter.speaker = speaker;
        }
        world +>:HasShooter:+> shooter;
        world +>:HasSignal:+> shooter.activation;
    }
}
