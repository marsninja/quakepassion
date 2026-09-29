"""Missile and gib trails, laid from where each was when its trail was last
laid to where it is now, as the clients do every frame: Q1
CL_RelinkEntities (R_RocketTrail by the model's flags), Q2
CL_AddPacketEntities (by the entity's effects: EF_ROCKET, EF_BLASTER,
EF_GRENADE, EF_GIB, and EF_BFG's and EF_TELEPORTER's particles laid anew
each client frame), Q3 CG_Missile's missileTrailFunc (the rocket's and
grenade's smoke) and a gib's LETT_BLOOD trail.

Each missile or gib keeps its trail state on a TrailEmitter node: where the
trail last reached, Q2's diminishing trail count (centity_t trailcount,
1024 when the entity first appears), Q3's trailTime, and the client frame
(the effect time) it last laid particles on.

A client frame is a drawn frame at a new effect time. The Q2 client runs a
frame at most cl_maxfps times a second and lays EF_BFG's and EF_TELEPORTER's
particles once in each; here the effect clock moves on with the physics
tick (120 a second, as if cl_maxfps were 120), so a frame drawn at a time
already laid lays nothing, and a slower drawing rate lays fewer, just as a
slower client does."""
import from .world { World }
import from .combat { Projectile, HasProjectile }
import from .gibs { Gib, HasGib }
import from .fixtures { Fixture, HasFixture }
import from .models { ModelResource, UsesModel }
import from .particle_field {
    ParticleField,
    HasParticles,
    quake_rocket_trail,
    quake_trail_kind,
    quake2_rocket_trail,
    quake2_blaster_trail,
    quake2_diminishing_trail,
    quake3_smoke_trail,
    quake3_blood_trail,
    quake2_teleporter_particles,
    quake2_bfg_particles
}
import from ..math.vec3 { Vec3 }
import from ..math.interpolation { TickBlend }

node TrailEmitter {
    has last: Vec3 = Vec3(),
        count: int = 1024,
        since: float = 0.0,
        framed: float = -1.0;

    """Whether this draw is a new client frame for the emitter (its effect
    time moved on since it last laid a frame's particles), noting it so."""
    def new_frame(clock: float) -> bool {
        if clock <= self.framed {
            return False;
        }
        self.framed = clock;
        return True;
    }
}

edge LeavesTrail: Projectile | Gib | Fixture --> TrailEmitter {}

"""Q1 R_RocketTrail types of the missiles whose models carry trail flags
(missile.mdl and lavaball.mdl EF_ROCKET, grenade.mdl EF_GRENADE, w_spike.mdl
EF_TRACER, k_spike.mdl EF_TRACER2, v_spike.mdl EF_TRACER3, zom_gib.mdl
EF_ZOMGIB); the spikes and the enforcer's laser.mdl carry none."""
glob QUAKE_MISSILE_TRAILS: dict[str, int] = {
    "q1_rocket": 0,
    "q1_lavaball": 0,
    "q1_grenade": 1,
    "q1_wizspike": 3,
    "q1_knightspike": 5,
    "q1_zombiegib": 4,
    "q1_vorepod": 6
};

"""Lay every missile's and gib's trail up to where the frame draws it (`blend`
of the way through the last physics tick, as the clients lay trails to the
interpolated origin)."""
walker EmitTrails {
    has field: ParticleField | None = None,
        blend: TickBlend = TickBlend();

    can begin with World entry {
        found = [here->:HasParticles:->][?:ParticleField];
        if not found {
            return;
        }
        self.field = found[0];
        visit [here->:HasProjectile:->];
        visit [here->:HasGib:->];
        visit [here->:HasFixture:->];
    }

    """The emitter of a missile, gib or fixture, made where it first shows
    (its first trail runs from there, so it lays nothing)."""
    def emitter_of(owner: Projectile | Gib | Fixture, at: Vec3) -> TrailEmitter {
        emitters = [owner->:LeavesTrail:->][?:TrailEmitter];
        if emitters {
            return emitters[0];
        }
        field = self.field;
        emitter = TrailEmitter(last=at.add(Vec3()), since=field.clock if field is not None else 0.0);
        owner +>:LeavesTrail:+> emitter;
        return emitter;
    }

    can missile with Projectile entry {
        field = self.field;
        if field is None or here.phase != 0 {
            return;
        }
        end = self.blend.place(here.tick_pose, here.pos);
        emitter = self.emitter_of(here, end);
        effect = here.effect;
        start = emitter.last;
        if effect in QUAKE_MISSILE_TRAILS {
            quake_rocket_trail(field, start, end, QUAKE_MISSILE_TRAILS[effect]);
        } elif effect == "q2_rocket" {
            emitter.count = quake2_rocket_trail(field, start, end, emitter.count);
        } elif effect == "q2_bolt" {
            quake2_blaster_trail(field, start, end);
        } elif effect in ["q2_grenade", "q2_handgrenade"] {
            emitter.count = quake2_diminishing_trail(field, start, end, emitter.count, False);
        } elif effect == "q2_bfg" {
            if emitter.new_frame(field.clock) {
                quake2_bfg_particles(field, end);
            }
        } elif effect in ["q3_rocket", "q3_grenade"] {
            # CG_RocketTrail: a stationary missile tosses up no smoke.
            if here.velocity.length() > 0.0 {
                rocket = effect == "q3_rocket";
                emitter.since = quake3_smoke_trail(
                    field, start, end, emitter.since, field.clock, 64.0 if rocket else 32.0, 2.0 if rocket else 0.7
                );
            }
            emitter.since = field.clock;
        }
        emitter.last = end.add(Vec3());
    }

    can gib with Gib entry {
        field = self.field;
        if field is None {
            return;
        }
        end = self.blend.place(here.tick_pose, here.pos);
        emitter = self.emitter_of(here, end);
        start = emitter.last;
        if field.game == "q1" {
            # The gib's model flags choose its trail (EF_GIB blood).
            for resource in [here.visual->:UsesModel:->][?:ModelResource] {
                kind = quake_trail_kind(resource.model.flags);
                if kind >= 0 {
                    quake_rocket_trail(field, start, end, kind);
                }
                break;
            }
        } elif field.game == "q2" {
            emitter.count = quake2_diminishing_trail(field, start, end, emitter.count, True);
        } elif field.game == "q3" {
            if not here.resting {
                quake3_blood_trail(field, start, end, emitter.since, field.clock);
            }
            emitter.since = field.clock;
        }
        emitter.last = end.add(Vec3());
    }

    """EF_TELEPORTER (CL_TeleporterParticles): eight green specks rising from
    the pad each client frame."""
    can sparkle with Fixture entry {
        field = self.field;
        if field is None or here.effect != "teleporter" {
            return;
        }
        if self.emitter_of(here, here.pos).new_frame(field.clock) {
            quake2_teleporter_particles(field, here.pos);
        }
    }
}
