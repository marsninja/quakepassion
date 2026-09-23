"""Bounded, transient combat feedback; never consumes gameplay random numbers."""
import from .world { World }
import from ..math.vec3 { Vec3 }

edge HasTrail: World --> ShotTrail {}
node ShotTrail {
    has start: Vec3,
        finish: Vec3,
        remaining: float = 0.2,
        kind: str = "rail";
}

def rail_trail(world: World, start: Vec3, finish: Vec3) {
    if len([world->:HasTrail:->]) < 64 {
        world +>:HasTrail:+> ShotTrail(start=start.add(Vec3()), finish=finish);
    }
}

# Monster beams (lightning, drains) share the bounded trail budget.
def beam_trail(world: World, start: Vec3, finish: Vec3, kind: str) {
    if len([world->:HasTrail:->]) < 64 {
        world +>:HasTrail:+> ShotTrail(
            start=start.add(Vec3()), finish=finish, kind=kind, remaining=0.15
        );
    }
}

edge HasParticle: World --> ImpactParticle {}
node ImpactParticle {
    has pos: Vec3,
        velocity: Vec3,
        blood: bool = False,
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

walker ParticleTick {
    has dt: float,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        visit [here->:HasParticle:->];
        visit [here->:HasTrail:->];
    }

    can fade with ShotTrail entry {
        here.remaining -= self.dt;
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
        here.velocity.z -= 160.0 * self.dt;
    }
}
