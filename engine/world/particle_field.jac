"""The particles of Q1 (r_part.c) and Q2 (cl_fx.c), and Q3's smoke puffs
(cg_effects.c CG_SmokePuff local entities), as each client makes them.

Particles are spawned once and never updated: each is its spawn record, and
where it is and what colour at any later time follow in closed form from the
original per-frame rules (evaluated on the GPU by the effect renderer, and
by `particle_state` here). Q1 kinds (ptype_t) integrate R_DrawParticles'
steps: gravity of sv_gravity * 0.05 a second (fire rises by it), explosion
velocities growing 4 times a second or shrinking by their own speed, and
colour ramps advancing 5, 10 or 15 steps a second until they run out. Q2
particles are CL_AddParticles' org + vel t + accel t^2, their alpha falling
by alphavel. A particle's life is `life` seconds from `born`.

Q3 trails are smoke puffs: sprites of a shader that drift, grow and fade
(LE_SCALE_FADE, LE_FALL_SCALE_FADE).

Randomness is the field's own rand() (a cosmetic stream, never gameplay
random numbers)."""
import math;
import from .world { World }
import from ..math.vec3 { Vec3 }

# Q1 ptype_t, then Q2's single particle model and a plain coloured spark
# (Q3 and Passion impacts, which have no palette).
glob PARTICLE_STATIC: int = 0,
     PARTICLE_GRAV: int = 1,
     PARTICLE_SLOWGRAV: int = 2,
     PARTICLE_FIRE: int = 3,
     PARTICLE_EXPLODE: int = 4,
     PARTICLE_EXPLODE2: int = 5,
     PARTICLE_BLOB: int = 6,
     PARTICLE_BLOB2: int = 7,
     PARTICLE_QUAKE2: int = 8,
     PARTICLE_SPARK: int = 9;

# r_part.c ramp1-ramp3: the fire and explosion colour ramps.
glob QUAKE_RAMP1: list[int] = [111, 109, 107, 105, 103, 101, 99, 97],
     QUAKE_RAMP2: list[int] = [111, 110, 109, 108, 107, 106, 104, 102],
     QUAKE_RAMP3: list[int] = [109, 107, 6, 5, 4, 3, 0, 0];

# sv_gravity 800 times R_DrawParticles' 0.05; Q2 PARTICLE_GRAVITY.
glob QUAKE_PARTICLE_GRAVITY: float = 40.0,
     QUAKE2_PARTICLE_GRAVITY: float = 40.0;

# The most particles alive at once (r_part.c MAX_PARTICLES 2048; Q2 4096).
glob PARTICLE_LIMIT: int = 4096;
glob PUFF_LIMIT: int = 512;

"""One particle as spawned. `color` is a palette index (or, for a spark,
0xRRGGBB); `ramp` a Q1 ramp position; `alpha` and `fade` Q2's alpha and
alphavel."""
obj Particle {
    has origin: Vec3,
        velocity: Vec3 = Vec3(),
        accel: Vec3 = Vec3(),
        born: float = 0.0,
        life: float = 1.0,
        kind: int = PARTICLE_STATIC,
        color: int = 0,
        ramp: float = 0.0,
        alpha: float = 1.0,
        fade: float = 0.0;
}

"""Where a particle is at a time, its colour (palette index or spark RGB) and
opacity, and whether it still shows."""
obj ParticleState {
    has position: Vec3 = Vec3(),
        color: int = 0,
        alpha: float = 1.0,
        alive: bool = False;
}

"""Q3 CG_SmokePuff: a sprite of `shader` `radius` across (growing to it from
8 as it fades, or with `fall`, from 16 while dropping `fall` units), its
colour and alpha fading from `color`/`alpha` over its life, drifting at
`velocity`, turned by `rotation` degrees."""
obj Puff {
    has origin: Vec3,
        velocity: Vec3 = Vec3(),
        radius: float = 8.0,
        color: Vec3 = Vec3(x=1.0, y=1.0, z=1.0),
        alpha: float = 1.0,
        born: float = 0.0,
        life: float = 1.0,
        shader: str = "",
        rotation: float = 0.0,
        fall: float = 0.0;
}

"""A Q3 puff at a time: its centre, radius and alpha, or not shown."""
obj PuffState {
    has position: Vec3 = Vec3(),
        radius: float = 0.0,
        alpha: float = 0.0,
        alive: bool = False;
}

"""A world's particles and puffs. `fresh` are the particles spawned since the
renderer last took them into its ring; `clock` the effect time they are born
on (it runs with the simulation); `seed` the rand() stream; `tracers`
R_RocketTrail's static tracercount."""
node ParticleField {
    has game: str = "",
        clock: float = 0.0,
        seed: int = 1,
        tracers: int = 0,
        fresh: list[Particle] = [],
        puffs: list[Puff] = [];

    """Q1/Q2 rand(): 0 to 32767."""
    def rand() -> int {
        self.seed = (self.seed * 1103515245 + 12345) & 2147483647;
        return (self.seed >> 16) & 32767;
    }

    """Q2 frand(): 0 to 1."""
    def frand() -> float {
        return float(self.rand() & 32767) / 32767.0;
    }

    """Q2 crand(): -1 to 1."""
    def crand() -> float {
        return float(self.rand() & 32767) / 32767.0 * 2.0 - 1.0;
    }

    """C's rand() % n for a possibly negative-offset spread (always positive
    here, as rand() is)."""
    def roll(n: int) -> int {
        return self.rand() % n;
    }

    """Spawn a particle. Unless a renderer takes them, the oldest half give
    way once the limit is reached (the ring would have overwritten them)."""
    def add(particle: Particle) {
        if len(self.fresh) >= PARTICLE_LIMIT {
            self.fresh = self.fresh[PARTICLE_LIMIT // 2:];
        }
        self.fresh.append(particle);
    }

    def add_puff(puff: Puff) {
        if len(self.puffs) >= PUFF_LIMIT {
            self.puffs = self.puffs[PUFF_LIMIT // 2:];
        }
        self.puffs.append(puff);
    }
}

edge HasParticles: World --> ParticleField {}

"""The world's particle field, made on first use."""
def particle_field(world: World, game: str = "") -> ParticleField {
    found = [world->:HasParticles:->][?:ParticleField];
    if found {
        if game and not found[0].game {
            found[0].game = game;
        }
        return found[0];
    }
    field = ParticleField(game=game);
    world +>:HasParticles:+> field;
    return field;
}

"""A Q1 particle's ramp colour and end, or the particle's own colour."""
def quake_ramp(particle: Particle, t: float) -> tuple[int, bool] {
    kind = particle.kind;
    if kind == PARTICLE_FIRE {
        step = particle.ramp + 5.0 * t;
        return (QUAKE_RAMP3[int(step)] if step < 6.0 else 0, step < 6.0);
    }
    if kind == PARTICLE_EXPLODE {
        step = particle.ramp + 10.0 * t;
        return (QUAKE_RAMP1[int(step)] if step < 8.0 else 0, step < 8.0);
    }
    if kind == PARTICLE_EXPLODE2 {
        step = particle.ramp + 15.0 * t;
        return (QUAKE_RAMP2[int(step)] if step < 8.0 else 0, step < 8.0);
    }
    return (particle.color, True);
}

"""Where a particle is at `now` (the GPU evaluates the same)."""
def particle_state(particle: Particle, now: float) -> ParticleState {
    t = now - particle.born;
    if t < 0.0 or t > particle.life {
        return ParticleState();
    }
    o = particle.origin;
    v = particle.velocity;
    kind = particle.kind;
    g = QUAKE_PARTICLE_GRAVITY;
    position = o.add(v.scale(t));
    alpha = 1.0;
    color = particle.color;
    if kind in [PARTICLE_GRAV, PARTICLE_SLOWGRAV] {
        position = position.sub(Vec3(z=0.5 * g * t * t));
    } elif kind == PARTICLE_FIRE {
        position = position.add(Vec3(z=0.5 * g * t * t));
    } elif kind in [PARTICLE_EXPLODE, PARTICLE_BLOB] {
        # v' = 4v, less gravity: v = g/4 + (v0 - g/4) e^4t.
        grow = (math.exp(4.0 * t) - 1.0) / 4.0;
        position = o.add(v.scale(grow)).add(Vec3(z=g / 4.0 * (t - grow)));
    } elif kind == PARTICLE_EXPLODE2 {
        # v' = -v, less gravity: v = -g + (v0 + g) e^-t.
        slow = 1.0 - math.exp(-t);
        position = o.add(v.scale(slow)).add(Vec3(z=g * (slow - t)));
    } elif kind == PARTICLE_BLOB2 {
        # Across: v' = -4v; up: gravity only.
        slow = (1.0 - math.exp(-4.0 * t)) / 4.0;
        position = Vec3(x=o.x + v.x * slow, y=o.y + v.y * slow, z=o.z + v.z * t - 0.5 * g * t * t);
    } elif kind in [PARTICLE_QUAKE2, PARTICLE_SPARK] {
        position = position.add(particle.accel.scale(t * t));
        alpha = particle.alpha + particle.fade * t;
        if alpha <= 0.0 {
            return ParticleState();
        }
        alpha = min(1.0, alpha);
    }
    ramp = quake_ramp(particle, t);
    if not ramp[1] {
        return ParticleState();
    }
    return ParticleState(position=position, color=ramp[0], alpha=alpha, alive=True);
}

"""A Q3 puff at `now`: LE_SCALE_FADE grows from 8 to 8 + radius as its
alpha falls to nothing (and is gone once the eye is inside it);
LE_FALL_SCALE_FADE grows from 16 while it drops `fall` units."""
def puff_state(puff: Puff, now: float, eye: Vec3) -> PuffState {
    t = now - puff.born;
    if t < 0.0 or t > puff.life {
        return PuffState();
    }
    left = (puff.life - t) / puff.life;
    position = puff.origin.add(puff.velocity.scale(t));
    radius = puff.radius * (1.0 - left) + 8.0;
    if puff.fall != 0.0 {
        position = puff.origin.sub(Vec3(z=(1.0 - left) * puff.fall));
        radius = puff.radius * (1.0 - left) + 16.0;
    } elif position.sub(eye).length() < puff.radius {
        return PuffState();
    }
    return PuffState(position=position, radius=radius, alpha=puff.alpha * left, alive=True);
}

# ---------------------------------------------------------------------------
# Quake 1 (r_part.c)

"""R_RocketTrail from `start` to `end`: 0 rocket fire, 1 grenade smoke, 2
blood (EF_GIB), 3 wizard and 5 hell knight tracers (EF_TRACER,
EF_TRACER2), 4 slight blood (EF_ZOMGIB), 6 the vore's trail (EF_TRACER3).
A particle every 3 units, trails live 2 seconds."""
def quake_rocket_trail(field: ParticleField, start: Vec3, end: Vec3, kind: int) {
    along = end.sub(start);
    length = along.length();
    if length <= 0.0 {
        return;
    }
    step = along.scale(1.0 / length);
    point = start.add(Vec3());
    while length > 0.0 {
        length -= 3.0;
        particle = Particle(origin=point, born=field.clock, life=2.0);
        if kind == 0 or kind == 1 {
            particle.ramp = float(field.rand() & 3) + (2.0 if kind == 1 else 0.0);
            particle.kind = PARTICLE_FIRE;
            particle.origin = quake_jitter(field, point, 6, 3);
        } elif kind == 2 or kind == 4 {
            particle.kind = PARTICLE_GRAV;
            particle.color = 67 + (field.rand() & 3);
            particle.origin = quake_jitter(field, point, 6, 3);
            if kind == 4 {
                length -= 3.0;
            }
        } elif kind == 3 or kind == 5 {
            particle.life = 0.5;
            particle.kind = PARTICLE_STATIC;
            particle.color = (52 if kind == 3 else 230) + ((field.tracers & 4) << 1);
            field.tracers += 1;
            if field.tracers & 1 != 0 {
                particle.velocity = Vec3(x=30.0 * step.y, y=-30.0 * step.x);
            } else {
                particle.velocity = Vec3(x=-30.0 * step.y, y=30.0 * step.x);
            }
        } elif kind == 6 {
            particle.color = 9 * 16 + 8 + (field.rand() & 3);
            particle.kind = PARTICLE_STATIC;
            particle.life = 0.3;
            particle.origin = Vec3(
                x=point.x + float((field.rand() & 15) - 8),
                y=point.y + float((field.rand() & 15) - 8),
                z=point.z + float((field.rand() & 15) - 8)
            );
        }
        field.add(particle);
        point = point.add(step);
    }
}

"""`point` moved by (rand() % span) - offset on each axis."""
def quake_jitter(field: ParticleField, point: Vec3, span: int, offset: int) -> Vec3 {
    return Vec3(
        x=point.x + float(field.roll(span) - offset),
        y=point.y + float(field.roll(span) - offset),
        z=point.z + float(field.roll(span) - offset)
    );
}

"""R_ParticleExplosion (TE_EXPLOSION): 1024 particles, half on ramp1 growing
outward, half on ramp2 slowing, for up to 5 seconds."""
def quake_particle_explosion(field: ParticleField, origin: Vec3) {
    for i in range(1024) {
        field.add(
            Particle(
                origin=quake_jitter(field, origin, 32, 16),
                velocity=Vec3(x=float(field.roll(512) - 256), y=float(field.roll(512) - 256), z=float(field.roll(512) - 256)),
                born=field.clock,
                life=5.0,
                kind=PARTICLE_EXPLODE if i & 1 else PARTICLE_EXPLODE2,
                ramp=float(field.rand() & 3)
            )
        );
    }
}

"""R_BlobExplosion (TE_TAREXPLOSION, the spawn's burst): 1024 particles,
purple blobs growing and blue ones drifting down, a second or so."""
def quake_blob_explosion(field: ParticleField, origin: Vec3) {
    for i in range(1024) {
        life = 1.0 + float(field.rand() & 8) * 0.05;
        odd = i & 1 != 0;
        color = (66 + field.roll(6)) if odd else (150 + field.roll(6));
        field.add(
            Particle(
                origin=quake_jitter(field, origin, 32, 16),
                velocity=Vec3(x=float(field.roll(512) - 256), y=float(field.roll(512) - 256), z=float(field.roll(512) - 256)),
                born=field.clock,
                life=life,
                kind=PARTICLE_BLOB if odd else PARTICLE_BLOB2,
                color=color
            )
        );
    }
}

"""R_RunParticleEffect (TE_GUNSHOT, TE_SPIKE, SpawnBlood's particle()):
`count` specks of `color`'s row, drifting along `direction` * 15 under light
gravity, living up to 0.4 seconds; a count of 1024 is an explosion."""
def quake_particle_effect(field: ParticleField, origin: Vec3, direction: Vec3, color: int, count: int) {
    if count == 1024 {
        quake_particle_explosion(field, origin);
        return;
    }
    for i in range(count) {
        field.add(
            Particle(
                origin=Vec3(
                    x=origin.x + float((field.rand() & 15) - 8),
                    y=origin.y + float((field.rand() & 15) - 8),
                    z=origin.z + float((field.rand() & 15) - 8)
                ),
                velocity=direction.scale(15.0),
                born=field.clock,
                life=0.1 * float(field.roll(5)),
                kind=PARTICLE_SLOWGRAV,
                color=(color & ~7) + (field.rand() & 7)
            )
        );
    }
}

"""R_LavaSplash (TE_LAVASPLASH, Chthon's death): fire-coloured specks rising
out of a 256-unit square."""
def quake_lava_splash(field: ParticleField, origin: Vec3) {
    for i in range(-16, 16) {
        for j in range(-16, 16) {
            life = 2.0 + float(field.rand() & 31) * 0.02;
            color = 224 + (field.rand() & 7);
            direction = Vec3(x=float(j * 8 + (field.rand() & 7)), y=float(i * 8 + (field.rand() & 7)), z=256.0);
            start = Vec3(x=origin.x + direction.x, y=origin.y + direction.y, z=origin.z + float(field.rand() & 63));
            speed = 50.0 + float(field.rand() & 63);
            field.add(
                Particle(origin=start, velocity=direction.normalized().scale(speed), born=field.clock, life=life, kind=PARTICLE_SLOWGRAV, color=color)
            );
        }
    }
}

"""R_TeleportSplash (TE_TELEPORT): grey specks thrown out of a box around the
arrival point."""
def quake_teleport_splash(field: ParticleField, origin: Vec3) {
    for i in range(-16, 16, 4) {
        for j in range(-16, 16, 4) {
            for k in range(-24, 32, 4) {
                life = 0.2 + float(field.rand() & 7) * 0.02;
                color = 7 + (field.rand() & 7);
                start = Vec3(
                    x=origin.x + float(i + (field.rand() & 3)),
                    y=origin.y + float(j + (field.rand() & 3)),
                    z=origin.z + float(k + (field.rand() & 3))
                );
                direction = Vec3(x=float(j * 8), y=float(i * 8), z=float(k * 8)).normalized();
                speed = 50.0 + float(field.rand() & 63);
                field.add(
                    Particle(origin=start, velocity=direction.scale(speed), born=field.clock, life=life, kind=PARTICLE_SLOWGRAV, color=color)
                );
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Quake 2 (cl_fx.c)

"""A Q2 particle: alpha 1 falling by `fade` a second (its life ends at 0)."""
def quake2_particle(field: ParticleField, origin: Vec3, velocity: Vec3, accel: Vec3, color: int, fade: float) -> Particle {
    return Particle(
        origin=origin,
        velocity=velocity,
        accel=accel,
        born=field.clock,
        life=1.0 / max(0.0001, -fade),
        kind=PARTICLE_QUAKE2,
        color=color,
        alpha=1.0,
        fade=fade
    );
}

"""CL_ParticleEffect (TE_GUNSHOT 0/40, TE_SHOTGUN 0/20, TE_BLOOD 0xe8/60,
TE_SPARKS 0xe0/6, target_splash): `count` specks of `color`'s row spread
along `direction`, falling and fading in about half a second."""
def quake2_particle_effect(field: ParticleField, origin: Vec3, direction: Vec3, color: int, count: int) {
    for i in range(count) {
        shade = color + (field.rand() & 7);
        d = float(field.rand() & 31);
        start = Vec3(
            x=origin.x + float((field.rand() & 7) - 4) + d * direction.x,
            y=origin.y + float((field.rand() & 7) - 4) + d * direction.y,
            z=origin.z + float((field.rand() & 7) - 4) + d * direction.z
        );
        velocity = Vec3(x=field.crand() * 20.0, y=field.crand() * 20.0, z=field.crand() * 20.0);
        field.add(
            quake2_particle(field, start, velocity, Vec3(z=-QUAKE2_PARTICLE_GRAVITY), shade, -1.0 / (0.5 + field.frand() * 0.3))
        );
    }
}

"""CL_ExplosionParticles (TE_ROCKET_EXPLOSION, TE_GRENADE_EXPLOSION): 256
yellow-orange specks thrown up to 192 units a second."""
def quake2_explosion_particles(field: ParticleField, origin: Vec3) {
    for i in range(256) {
        shade = 224 + (field.rand() & 7);
        start = Vec3(
            x=origin.x + float(field.roll(32) - 16),
            y=origin.y + float(field.roll(32) - 16),
            z=origin.z + float(field.roll(32) - 16)
        );
        velocity = Vec3(x=float(field.roll(384) - 192), y=float(field.roll(384) - 192), z=float(field.roll(384) - 192));
        field.add(
            quake2_particle(field, start, velocity, Vec3(z=-QUAKE2_PARTICLE_GRAVITY), shade, -0.8 / (0.5 + field.frand() * 0.3))
        );
    }
}

"""CL_BlasterParticles (TE_BLASTER): 40 yellow specks off the wall."""
def quake2_blaster_particles(field: ParticleField, origin: Vec3, direction: Vec3) {
    for i in range(40) {
        shade = 224 + (field.rand() & 7);
        d = float(field.rand() & 15);
        start = Vec3(
            x=origin.x + float((field.rand() & 7) - 4) + d * direction.x,
            y=origin.y + float((field.rand() & 7) - 4) + d * direction.y,
            z=origin.z + float((field.rand() & 7) - 4) + d * direction.z
        );
        velocity = Vec3(
            x=direction.x * 30.0 + field.crand() * 40.0,
            y=direction.y * 30.0 + field.crand() * 40.0,
            z=direction.z * 30.0 + field.crand() * 40.0
        );
        field.add(
            quake2_particle(field, start, velocity, Vec3(z=-QUAKE2_PARTICLE_GRAVITY), shade, -1.0 / (0.5 + field.frand() * 0.3))
        );
    }
}

"""CL_TeleportParticles (a player teleporting): grey specks thrown out of a
box around the arrival point."""
def quake2_teleport_particles(field: ParticleField, origin: Vec3) {
    for i in range(-16, 17, 4) {
        for j in range(-16, 17, 4) {
            for k in range(-16, 33, 4) {
                shade = 7 + (field.rand() & 7);
                fade = -1.0 / (0.3 + float(field.rand() & 7) * 0.02);
                start = Vec3(
                    x=origin.x + float(i + (field.rand() & 3)),
                    y=origin.y + float(j + (field.rand() & 3)),
                    z=origin.z + float(k + (field.rand() & 3))
                );
                direction = Vec3(x=float(j * 8), y=float(i * 8), z=float(k * 8)).normalized();
                speed = 50.0 + float(field.rand() & 63);
                field.add(
                    quake2_particle(field, start, direction.scale(speed), Vec3(z=-QUAKE2_PARTICLE_GRAVITY), shade, fade)
                );
            }
        }
    }
}

"""CL_TeleporterParticles (EF_TELEPORTER, a misc_teleporter's pad): eight
green specks rising from around the pad."""
def quake2_teleporter_particles(field: ParticleField, origin: Vec3) {
    for i in range(8) {
        start = Vec3(
            x=origin.x - 16.0 + float(field.rand() & 31),
            y=origin.y - 16.0 + float(field.rand() & 31),
            z=origin.z - 8.0 + float(field.rand() & 7)
        );
        velocity = Vec3(x=field.crand() * 14.0, y=field.crand() * 14.0, z=80.0 + float(field.rand() & 7));
        field.add(quake2_particle(field, start, velocity, Vec3(z=-QUAKE2_PARTICLE_GRAVITY), 219, -0.5));
    }
}

"""CL_RailTrail: a spiral of blue specks a unit apart, three units out and
drifting outward, round a core of grey specks every 0.75 units."""
def quake2_rail_trail(field: ParticleField, start: Vec3, end: Vec3) {
    along = end.sub(start);
    length = along.length();
    if length <= 0.0 {
        return;
    }
    axis = along.scale(1.0 / length);
    # MakeNormalVectors: a right vector off the axis, and up across both.
    right = Vec3(x=axis.z, y=-axis.x, z=axis.y);
    right = right.sub(axis.scale(right.dot(axis))).normalized();
    up = right.cross(axis);
    i = 0;
    while float(i) < length {
        d = float(i) * 0.1;
        spin = right.scale(math.cos(d)).add(up.scale(math.sin(d)));
        fade = -1.0 / (1.0 + field.frand() * 0.2);
        color = 116 + (field.rand() & 7);
        field.add(quake2_particle(field, start.add(axis.scale(float(i))).add(spin.scale(3.0)), spin.scale(6.0), Vec3(), color, fade));
        i += 1;
    }
    left = length;
    point = start.add(Vec3());
    step = axis.scale(0.75);
    while left > 0.0 {
        left -= 0.75;
        fade = -1.0 / (0.6 + field.frand() * 0.2);
        color = field.rand() & 15;
        origin = Vec3(x=point.x + field.crand() * 3.0, y=point.y + field.crand() * 3.0, z=point.z + field.crand() * 3.0);
        velocity = Vec3(x=field.crand() * 3.0, y=field.crand() * 3.0, z=field.crand() * 3.0);
        field.add(quake2_particle(field, origin, velocity, Vec3(), color, fade));
        point = point.add(step);
    }
}

"""CL_BlasterTrail (EF_BLASTER): a yellow speck every 5 units."""
def quake2_blaster_trail(field: ParticleField, start: Vec3, end: Vec3) {
    along = end.sub(start);
    length = along.length();
    if length <= 0.0 {
        return;
    }
    step = along.scale(5.0 / length);
    point = start.add(Vec3());
    while length > 0.0 {
        length -= 5.0;
        fade = -1.0 / (0.3 + field.frand() * 0.2);
        origin = Vec3(x=point.x + field.crand(), y=point.y + field.crand(), z=point.z + field.crand());
        velocity = Vec3(x=field.crand() * 5.0, y=field.crand() * 5.0, z=field.crand() * 5.0);
        field.add(quake2_particle(field, origin, velocity, Vec3(), 224, fade));
        point = point.add(step);
    }
}

"""CL_DiminishingTrail (EF_GIB blood, EF_GRENADE and the rocket's smoke): a
speck every half unit while `count` (the entity's trailcount, 1024 at
first) beats rand()&1023, the count dropping 5 a speck to no less than 100;
wider and faster while it is high. Returns the new count."""
def quake2_diminishing_trail(field: ParticleField, start: Vec3, end: Vec3, count: int, gib: bool) -> int {
    along = end.sub(start);
    length = along.length();
    if length <= 0.0 {
        return count;
    }
    step = along.scale(0.5 / length);
    point = start.add(Vec3());
    spread = 1.0;
    speed = 5.0;
    if count > 900 {
        spread = 4.0;
        speed = 15.0;
    } elif count > 800 {
        spread = 2.0;
        speed = 10.0;
    }
    while length > 0.0 {
        length -= 0.5;
        if (field.rand() & 1023) < count {
            origin = Vec3(
                x=point.x + field.crand() * spread,
                y=point.y + field.crand() * spread,
                z=point.z + field.crand() * spread
            );
            velocity = Vec3(x=field.crand() * speed, y=field.crand() * speed, z=field.crand() * speed);
            if gib {
                fade = -1.0 / (1.0 + field.frand() * 0.4);
                field.add(quake2_particle(field, origin, velocity.sub(Vec3(z=QUAKE2_PARTICLE_GRAVITY)), Vec3(), 232 + (field.rand() & 7), fade));
            } else {
                fade = -1.0 / (1.0 + field.frand() * 0.2);
                field.add(quake2_particle(field, origin, velocity, Vec3(z=20.0), 4 + (field.rand() & 7), fade));
            }
        }
        count = max(100, count - 5);
        point = point.add(step);
    }
    return count;
}

"""CL_RocketTrail (EF_ROCKET): the diminishing smoke, and a falling fire speck
one unit in eight. Returns the new trail count."""
def quake2_rocket_trail(field: ParticleField, start: Vec3, end: Vec3, count: int) -> int {
    count = quake2_diminishing_trail(field, start, end, count, False);
    along = end.sub(start);
    length = along.length();
    if length <= 0.0 {
        return count;
    }
    step = along.scale(1.0 / length);
    point = start.add(Vec3());
    while length > 0.0 {
        length -= 1.0;
        if (field.rand() & 7) == 0 {
            fade = -1.0 / (1.0 + field.frand() * 0.2);
            shade = 220 + (field.rand() & 3);
            origin = Vec3(x=point.x + field.crand() * 5.0, y=point.y + field.crand() * 5.0, z=point.z + field.crand() * 5.0);
            velocity = Vec3(x=field.crand() * 20.0, y=field.crand() * 20.0, z=field.crand() * 20.0);
            field.add(quake2_particle(field, origin, velocity, Vec3(z=-QUAKE2_PARTICLE_GRAVITY), shade, fade));
        }
        point = point.add(step);
    }
    return count;
}

# ---------------------------------------------------------------------------
# Quake 3 (cg_weapons.c, cg_effects.c)

"""CG_RocketTrail / CG_GrenadeTrail: a smokePuff every 50 ms of the missile's
flight (from `since` to `until`, positions along `start` to `end`), `radius`
across and living `life` seconds, a third opaque, each turned at random.
Returns the time of the last puff."""
def quake3_smoke_trail(field: ParticleField, start: Vec3, end: Vec3, since: float, until: float, radius: float, life: float) -> float {
    step = 0.05;
    t = step * float(int((since + step) / step + 0.0001));
    last = since;
    while t <= until + 0.0001 {
        share = (t - since) / (until - since) if until > since else 1.0;
        field.add_puff(
            Puff(
                origin=start.lerp(end, max(0.0, min(1.0, share))),
                radius=radius,
                alpha=0.33,
                born=t,
                life=life,
                shader="smokePuff",
                rotation=float(field.rand() % 360)
            )
        );
        last = t;
        t += step;
    }
    return last;
}

"""CG_BloodTrail (a gib's LETT_BLOOD): a bloodTrail puff every 150 ms, 20
across, falling 40 units over its 2 seconds."""
def quake3_blood_trail(field: ParticleField, start: Vec3, end: Vec3, since: float, until: float) -> float {
    step = 0.15;
    t = step * float(int((since + step) / step + 0.0001));
    last = since;
    while t <= until + 0.0001 {
        share = (t - since) / (until - since) if until > since else 1.0;
        field.add_puff(
            Puff(
                origin=start.lerp(end, max(0.0, min(1.0, share))),
                radius=20.0,
                alpha=1.0,
                born=t,
                life=2.0,
                shader="bloodTrail",
                fall=40.0
            )
        );
        last = t;
        t += step;
    }
    return last;
}

# ---------------------------------------------------------------------------
# Shared entry points

"""Plain sparks for games without a palette (Q3 and Passion impacts): dust,
blood or embers thrown along `direction`, fading within half a second."""
def spark_spray(field: ParticleField, origin: Vec3, direction: Vec3, color: int, count: int) {
    for i in range(count) {
        velocity = direction.scale(30.0 + float(field.rand() & 31)).add(
            Vec3(x=field.crand() * 25.0, y=field.crand() * 25.0, z=field.crand() * 25.0)
        );
        inward = velocity.dot(direction);
        if inward < 0.0 {
            velocity = velocity.sub(direction.scale(inward));
        }
        life = 0.25 + field.frand() * 0.3;
        field.add(
            Particle(
                origin=origin.add(direction),
                velocity=velocity,
                accel=Vec3(z=-80.0),
                born=field.clock,
                life=life,
                kind=PARTICLE_SPARK,
                color=color,
                alpha=1.0,
                fade=-1.0 / life
            )
        );
    }
}

"""Q1 R_RocketTrail's type for a model's flags (EF_ROCKET 1, EF_GRENADE 2,
EF_GIB 4, EF_TRACER 16, EF_ZOMGIB 32, EF_TRACER2 64, EF_TRACER3 128), in
CL_RelinkEntities' order; -1 for none."""
def quake_trail_kind(flags: int) -> int {
    if flags & 4 != 0 {
        return 2;
    }
    if flags & 32 != 0 {
        return 4;
    }
    if flags & 16 != 0 {
        return 3;
    }
    if flags & 64 != 0 {
        return 5;
    }
    if flags & 1 != 0 {
        return 0;
    }
    if flags & 2 != 0 {
        return 1;
    }
    if flags & 128 != 0 {
        return 6;
    }
    return -1;
}
