"""Bounded, transient combat feedback; never consumes gameplay random numbers."""
import math;
import from .world { World }
import from ..physics.collision { CollisionMap }
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

"""A scorch or bullet hole on a wall (Q3 cg_marks.c CG_ImpactMark): the mark
shader's square, `radius` from its centre, turned by `angle` on the surface
facing `normal`. Marks stay MARK_TOTAL_TIME and fade over the last
MARK_FADE_TIME; energy marks fade their alpha, the others their colour."""
edge HasMark: World --> ImpactMark {}
node ImpactMark {
    has pos: Vec3,
        normal: Vec3,
        shader: str,
        radius: float,
        angle: float = 0.0,
        color: Vec3 = Vec3(x=1.0, y=1.0, z=1.0),
        alpha_fade: bool = False,
        age: float = 0.0;
}

glob MARK_TOTAL_TIME: float = 10.0;
glob MARK_FADE_TIME: float = 1.0;
# cg_marks.c MAX_MARK_POLYS: the oldest mark gives way when the pool is full.
glob MAX_MARKS: int = 128;

"""A one-off sound where a shot struck (ricochets, blaster hits); the game
plays it once, as it plays an explosion's."""
edge HasImpactSound: World --> ImpactSound {}
node ImpactSound {
    has pos: Vec3,
        sound: str,
        heard: bool = False,
        remaining: float = 0.1;
}

"""A cosmetic roll in [0, 1) from where something struck, so impact sounds
and mark turns vary without consuming gameplay random numbers."""
def impact_roll(origin: Vec3, salt: float = 0.0) -> float {
    value = math.sin(origin.x * 12.9898 + origin.y * 78.233 + origin.z * 37.719 + salt) * 43758.5453;
    return value - math.floor(value);
}

"""Leave a mark, retiring the oldest when the pool is full."""
def impact_mark(
    world: World,
    shader: str,
    origin: Vec3,
    normal: Vec3,
    radius: float,
    color: Vec3 = Vec3(x=1.0, y=1.0, z=1.0),
    alpha_fade: bool = False,
    collision: CollisionMap | None = None
) {
    angle = impact_roll(origin, 3.0) * 2.0 * math.pi;
    facing = normal.normalized();
    if collision is not None {
        radius = mark_fit(collision, origin, facing, radius, angle);
    }
    marks = [world->:HasMark:->][?:ImpactMark];
    if len(marks) >= MAX_MARKS {
        oldest = marks[0];
        for mark in marks {
            if mark.age > oldest.age {
                oldest = mark;
            }
        }
        world del --> oldest;
    }
    world +>:HasMark:+> ImpactMark(
        pos=origin.add(Vec3()),
        normal=facing,
        shader=shader,
        radius=radius,
        angle=angle,
        color=color,
        alpha_fade=alpha_fade
    );
}

"""The two axes across a surface facing `normal`, turned by `angle`
(cg_marks.c: PerpendicularVector, then RotatePointAroundVector)."""
def mark_axes(normal: Vec3, angle: float) -> list[Vec3] {
    helper = Vec3(z=1.0) if abs(normal.z) < 0.9 else Vec3(x=1.0);
    first = normal.cross(helper).normalized();
    second = normal.cross(first).normalized();
    across = first.scale(math.cos(angle)).add(second.scale(math.sin(angle)));
    along = normal.cross(across).normalized();
    return [across, along];
}

"""How large a mark can lie flat on the surface it struck. Q3 clips each mark
to the world's faces (CM_MarkFragments); here a mark whose corners would hang
off an edge or corner shrinks until they all rest on the same plane."""
def mark_fit(
    collision: CollisionMap, origin: Vec3, normal: Vec3, radius: float, angle: float
) -> float {
    axes = mark_axes(normal, angle);
    size = radius;
    for attempt in range(3) {
        resting = True;
        for corner in [(1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)] {
            point = origin.add(axes[0].scale(corner[0] * size)).add(axes[1].scale(corner[1] * size));
            probe = collision.trace_point(point.add(normal.scale(2.0)), point.sub(normal.scale(2.0)));
            if probe.start_solid or probe.fraction >= 1.0 or probe.normal.dot(normal) < 0.99 {
                resting = False;
                break;
            }
        }
        if resting {
            return size;
        }
        size *= 0.5;
    }
    return size;
}

def impact_sound(world: World, origin: Vec3, sound: str) {
    if sound and len([world->:HasImpactSound:->]) < 16 {
        world +>:HasImpactSound:+> ImpactSound(pos=origin.add(Vec3()), sound=sound);
    }
}

"""The sound a shot makes striking a wall, by game and weapon or missile:
Q1 CL_ParseTEnt TE_SPIKE/TE_SUPERSPIKE (tink1 four times in five, else ric1,
ric2 or ric3), TE_WIZSPIKE, TE_KNIGHTSPIKE and Laser_Touch's enfstop; Q2
TE_GUNSHOT (ric1-3 three times in sixteen; TE_SHOTGUN is silent) and
TE_BLASTER's lashit; Q3 CG_MissileHitWall (the machine gun always
ricochets, the lightning gun hits)."""
def ricochet_sound(game: str, weapon: str, roll: float) -> str {
    if game == "q1" {
        if weapon in ["q1_nail", "q1_supernail"] {
            if roll < 0.8 {
                return "sound/weapons/tink1.wav";
            }
            pick = int((roll - 0.8) / 0.2 * 4.0);
            return "sound/weapons/ric" + ("1" if pick == 1 else ("2" if pick == 2 else "3")) + ".wav";
        }
        return {
            "q1_laser": "sound/enforcer/enfstop.wav",
            "q1_wizspike": "sound/wizard/hit.wav",
            "q1_knightspike": "sound/hknight/hit.wav"
        }.get(weapon, "");
    }
    if game == "q2" {
        if weapon in ["machinegun", "chaingun", "bullet"] {
            pick = int(roll * 16.0);
            return "sound/world/ric" + str(pick) + ".wav" if pick in [1, 2, 3] else "";
        }
        return "sound/weapons/lashit.wav" if weapon == "q2_bolt" else "";
    }
    if game == "q3" {
        pick = int(roll * 4.0);
        if weapon == "machinegun" {
            return "sound/weapons/machinegun/ric" + ("1" if pick == 0 else ("2" if pick == 1 else "3")) + ".wav";
        }
        if weapon == "lightning" {
            return "sound/weapons/lightning/lg_hit" + ("2" if pick < 2 else ("" if pick == 2 else "3")) + ".wav";
        }
    }
    return "";
}

"""Q3 CG_MissileHitWall's mark for each weapon: its shader, radius and
whether it fades its alpha (the energy marks) or its colour."""
obj MarkLook {
    has shader: str = "",
        radius: float = 0.0,
        alpha_fade: bool = False;
}

def mark_look(game: str, weapon: str) -> MarkLook {
    if game != "q3" {
        return MarkLook();
    }
    if weapon == "machinegun" {
        return MarkLook(shader="gfx/damage/bullet_mrk", radius=8.0);
    }
    if weapon == "shotgun" {
        return MarkLook(shader="gfx/damage/bullet_mrk", radius=4.0);
    }
    if weapon == "lightning" {
        return MarkLook(shader="gfx/damage/hole_lg_mrk", radius=12.0);
    }
    if weapon in ["q3_rocket", "q3_grenade"] {
        return MarkLook(shader="gfx/damage/burn_med_mrk", radius=64.0);
    }
    if weapon == "q3_bfg" {
        return MarkLook(shader="gfx/damage/burn_med_mrk", radius=32.0);
    }
    if weapon == "q3_plasma" {
        return MarkLook(shader="gfx/damage/plasma_mrk", radius=16.0, alpha_fade=True);
    }
    if weapon == "railgun" {
        return MarkLook(shader="gfx/damage/plasma_mrk", radius=24.0, alpha_fade=True);
    }
    return MarkLook();
}

# The rail mark takes the trail's colour (the magenta railDisc rings).
glob RAIL_MARK_COLOR: Vec3 = Vec3(x=1.0, y=0.0, z=1.0);

"""A shot striking the world at `origin` on a surface facing `normal`: its
ricochet sound, and in Q3 its mark on the world's own brushes. `surface` is
CollisionMap.surface_class: the sky takes nothing, SURF_NOMARKS no mark.
`model` is the brush model struck; movers take no marks, as Q3 marks only
the world. With `collision` a mark shrinks to stay on its surface."""
def wall_impact(
    world: World,
    game: str,
    weapon: str,
    origin: Vec3,
    normal: Vec3,
    surface: int = 0,
    model: int = 0,
    collision: CollisionMap | None = None
) {
    if surface >= 2 {
        return;
    }
    impact_sound(world, origin, ricochet_sound(game, weapon, impact_roll(origin)));
    look = mark_look(game, weapon);
    if look.shader and surface == 0 and model <= 0 {
        impact_mark(
            world,
            look.shader,
            origin,
            normal,
            look.radius,
            RAIL_MARK_COLOR if weapon == "railgun" else Vec3(x=1.0, y=1.0, z=1.0),
            look.alpha_fade,
            collision
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
        visit [here->:HasMark:->];
        visit [here->:HasImpactSound:->];
    }

    can wear with ImpactMark entry {
        here.age += self.dt;
        if here.age >= MARK_TOTAL_TIME and self.world is not None {
            self.world del --> here;
        }
    }

    can fade_sound with ImpactSound entry {
        here.remaining -= self.dt;
        if here.remaining <= 0.0 and self.world is not None {
            self.world del --> here;
        }
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
