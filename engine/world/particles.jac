"""Bounded, transient combat feedback; never consumes gameplay random numbers."""
import math;
import from .world { World }
import from ..math.vec3 { Vec3 }

edge HasTrail: World --> ShotTrail {}
node ShotTrail {
    has start: Vec3,
        finish: Vec3,
        remaining: float = 0.2,
        kind: str = "rail",
        lifetime: float = 0.2,
        age: float = 0.0;
}

"""A railgun trail. Q2 CL_RailTrail's particle spiral fades in about a
second; Q3 CG_RailTrail's core and rings last cg_railTrailTime (400 ms)."""
def rail_trail(world: World, start: Vec3, finish: Vec3, kind: str = "rail") {
    life = 0.2;
    if kind == "q2_rail" {
        life = 1.0;
    } elif kind == "q3_rail" {
        life = 0.4;
    }
    if len([world->:HasTrail:->]) < 64 {
        world +>:HasTrail:+> ShotTrail(
            start=start.add(Vec3()), finish=finish, kind=kind, remaining=life, lifetime=life
        );
    }
}

# Monster beams (lightning, drains) share the bounded trail budget.
def beam_trail(world: World, start: Vec3, finish: Vec3, kind: str) {
    if len([world->:HasTrail:->]) < 64 {
        world +>:HasTrail:+> ShotTrail(
            start=start.add(Vec3()), finish=finish, kind=kind, remaining=0.15, lifetime=0.15
        );
    }
}

edge HasParticle: World --> ImpactParticle {}
node ImpactParticle {
    has pos: Vec3,
        velocity: Vec3,
        blood: bool = False,
        fire: bool = False,
        remaining: float = 0.4,
        lifetime: float = 0.4;
}

def impact_spray(world: World, origin: Vec3, normal: Vec3, blood: bool = False) {
    count = len([world->:HasParticle:->]);
    # A pellet owns a small fan; saturation drops cosmetics, never damage.
    for i in range(min(8, max(0, 512 - count))) {
        jitter = Vec3(
            x=float((i * 7) % 11) - 5.0,
            y=float((i * 5) % 13) - 6.0,
            z=float((i * 3) % 7) - 3.0
        );
        velocity = normal.scale(30.0 + float(i) * 4.0).add(jitter.scale(5.0));
        # Keep debris on the visible side of its impact plane.
        inward = velocity.dot(normal);
        if inward < 0.0 {
            velocity = velocity.sub(normal.scale(inward));
        }
        life = 0.25 + float(i) * 0.035;
        world +>:HasParticle:+> ImpactParticle(
            pos=origin.add(normal.scale(1.0)),
            velocity=velocity,
            blood=blood,
            remaining=life,
            lifetime=life
        );
    }
}

"""How each game's explosion looks and sounds, and its dynamic light: Q1
BecomeExplosion (s_explod.spr, TE_EXPLOSION particles and light, r_exp3.wav),
Q2 CL_ParseTEnt (r_explode model, 350 light, rocket or grenade sound), Q3
CG_MissileHitWall (animated sprite, 300 light, rocket or plasma sound)."""
obj BlastLook {
    has lifetime: float = 0.6,
        light: Vec3 = Vec3(),
        light_radius: float = 0.0,
        sound: str = "",
        sparks: int = 0;
}

def blast_look(kind: str) -> BlastLook {
    if kind == "q1_explosion" {
        return BlastLook(
            lifetime=0.6,
            light=Vec3(x=1.0, y=0.6, z=0.3),
            light_radius=350.0,
            sound="sound/weapons/r_exp3.wav",
            sparks=48
        );
    }
    if kind == "q2_explosion" {
        return BlastLook(
            lifetime=1.4,
            light=Vec3(x=1.0, y=0.5, z=0.5),
            light_radius=350.0,
            sound="sound/weapons/ROCKLX1A.WAV",
            sparks=32
        );
    }
    if kind == "q2_grenade_explosion" {
        return BlastLook(
            lifetime=1.8,
            light=Vec3(x=1.0, y=0.5, z=0.5),
            light_radius=350.0,
            sound="sound/weapons/GRENLX1A.WAV",
            sparks=32
        );
    }
    if kind == "q3_rocket_explosion" {
        return BlastLook(
            lifetime=1.0,
            light=Vec3(x=1.0, y=0.75, z=0.0),
            light_radius=300.0,
            sound="sound/weapons/rocket/rocklx1a.wav"
        );
    }
    if kind == "q3_grenade_explosion" {
        return BlastLook(
            lifetime=0.6,
            light=Vec3(x=1.0, y=1.0, z=0.0),
            light_radius=300.0,
            sound="sound/weapons/rocket/rocklx1a.wav"
        );
    }
    if kind == "q3_plasma_explosion" {
        return BlastLook(lifetime=0.6, sound="sound/weapons/plasma/plasmx1a.wav");
    }
    if kind == "q3_bfg_explosion" {
        return BlastLook(lifetime=0.6, sound="sound/weapons/rocket/rocklx1a.wav");
    }
    return BlastLook(lifetime=0.5, sparks=24);
}

"""Which explosion a missile makes on bursting, by game and missile effect."""
def blast_kind(game: str, effect: str) -> str {
    if game == "q2" {
        if effect == "q2_bfg" {
            return "";
        }
        return "q2_grenade_explosion" if "grenade" in effect else "q2_explosion";
    }
    if game == "q3" {
        if effect in ["q3_grenade", "q3_plasma", "q3_bfg"] {
            return effect + "_explosion";
        }
        return "q3_rocket_explosion";
    }
    return "q1_explosion" if game == "q1" else "blast";
}

edge HasExplosion: World --> Explosion {}
node Explosion {
    has pos: Vec3,
        kind: str,
        lifetime: float = 0.6,
        age: float = 0.0,
        light: Vec3 = Vec3(),
        light_radius: float = 0.0,
        sound: str = "",
        heard: bool = False,
        variant: int = 0;
}

"""Start an explosion at `origin`: its look, light and sound, and a burst of
fire particles (Q1 R_ParticleExplosion, Q2 CL_ExplosionParticles)."""
def explode(world: World, origin: Vec3, kind: str) {
    if not kind {
        return;
    }
    blasts = [world->:HasExplosion:->];
    if len(blasts) >= 32 {
        return;
    }
    look = blast_look(kind);
    world +>:HasExplosion:+> Explosion(
        pos=origin.add(Vec3()),
        kind=kind,
        lifetime=look.lifetime,
        light=look.light,
        light_radius=look.light_radius,
        sound=look.sound,
        variant=len(blasts) + int(abs(origin.x + origin.y))
    );
    count = len([world->:HasParticle:->]);
    for i in range(min(look.sparks, max(0, 512 - count))) {
        # A fixed, even spray: no gameplay random numbers are consumed.
        heading = float(i) * 2.399963;
        rise = 1.0 - 2.0 * (float(i) + 0.5) / float(look.sparks);
        across = math.sqrt(max(0.0, 1.0 - rise * rise));
        speed = 160.0 + float((i * 37) % 97) * 1.6;
        velocity = Vec3(
            x=math.cos(heading) * across, y=math.sin(heading) * across, z=rise
        ).scale(speed);
        life = 0.45 + float((i * 13) % 7) * 0.08;
        world +>:HasParticle:+> ImpactParticle(
            pos=origin.add(Vec3()),
            velocity=velocity,
            fire=True,
            remaining=life,
            lifetime=life
        );
    }
}

walker ParticleTick {
    has dt: float,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        visit [here->:HasParticle:->];
        visit [here->:HasTrail:->];
        visit [here->:HasExplosion:->];
    }

    can burn with Explosion entry {
        here.age += self.dt;
        if here.age >= here.lifetime and self.world is not None {
            self.world del --> here;
        }
    }

    can fade with ShotTrail entry {
        here.remaining -= self.dt;
        here.age += self.dt;
        if here.remaining <= 0.0 and self.world is not None {
            self.world del --> here;
        }
    }

    can advance with ImpactParticle entry {
        here.remaining -= self.dt;
        if here.remaining <= 0.0 {
            if self.world is not None {
                self.world del --> here;
            }
            return;
        }
        here.pos = here.pos.add(here.velocity.scale(self.dt));
        # Explosion embers slow as they drift, as the Q1/Q2 ramps do.
        if here.fire {
            here.velocity = here.velocity.scale(max(0.0, 1.0 - 3.0 * self.dt));
        } else {
            here.velocity.z -= 160.0 * self.dt;
        }
    }
}
