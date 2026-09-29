"""Bounded, transient combat feedback; never consumes gameplay random numbers."""
import math;
import from .world { World }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }
import from .particle_field {
    ParticleField,
    HasParticles,
    Puff,
    particle_field,
    quake_particle_explosion,
    quake_particle_effect,
    quake_teleport_splash,
    quake2_particle_effect,
    quake2_explosion_particles,
    quake2_blaster_particles,
    quake2_teleport_particles,
    quake2_rail_trail,
    spark_spray
}

edge HasTrail: World --> ShotTrail {}
"""A beam or rail shown for a moment from `start` to `finish`: `width` is a
Q2 laser's diameter (target_laser's s.frame)."""
node ShotTrail {
    has start: Vec3,
        finish: Vec3,
        remaining: float = 0.2,
        kind: str = "rail",
        lifetime: float = 0.2,
        age: float = 0.0,
        width: float = 4.0;
}

"""A railgun trail. Q2 CL_RailTrail is particles (a blue spiral round a
grey core, fading in about a second); Q3 CG_RailTrail's core lasts
cg_railTrailTime (400 ms)."""
def rail_trail(world: World, start: Vec3, finish: Vec3, kind: str = "rail") {
    if kind == "q2_rail" {
        quake2_rail_trail(particle_field(world), start, finish);
        return;
    }
    life = 0.4 if kind == "q3_rail" else 0.2;
    if len([world->:HasTrail:->]) < 64 {
        world +>:HasTrail:+> ShotTrail(
            start=start.add(Vec3()), finish=finish, kind=kind, remaining=life, lifetime=life
        );
    }
}

# Monster beams (lightning, drains) share the bounded trail budget.
def beam_trail(world: World, start: Vec3, finish: Vec3, kind: str, width: float = 4.0) {
    if len([world->:HasTrail:->]) < 64 {
        world +>:HasTrail:+> ShotTrail(
            start=start.add(Vec3()), finish=finish, kind=kind, remaining=0.15, lifetime=0.15, width=width
        );
    }
}

"""A hitscan shot of `weapon` striking a wall or a body at `origin` on a
surface facing `normal`: Q1 TE_GUNSHOT (R_RunParticleEffect, 20 specks of
grey) or SpawnBlood (73, twice a pellet's 4 damage); Q2 TE_GUNSHOT (grey,
40) or TE_BLOOD (0xe8, 60); Q3 CG_Bleed on a body (the rail draws none, its
hits send no EV_MISSILE_HIT) and nothing on a wall, where the shot's
CG_MissileHitWall (wall_impact) makes its whole impact; Passion a small
spray of dust or blood."""
def impact_spray(world: World, origin: Vec3, normal: Vec3, blood: bool = False, weapon: str = "") {
    field = particle_field(world);
    if field.game == "q1" {
        quake_particle_effect(field, origin, normal.scale(4.0) if blood else Vec3(), 73 if blood else 0, 8 if blood else 20);
    } elif field.game == "q2" {
        quake2_particle_effect(field, origin, normal, 232 if blood else 0, 60 if blood else 40);
    } elif field.game == "q3" {
        if blood and weapon != "railgun" {
            quake3_bleed(world, origin);
        }
    } else {
        spark_spray(field, origin, normal, 11146255 if blood else 13810065, 8);
    }
}

"""A missile's own impact particles, by game and effect: Q1 CL_ParseTEnt
TE_SPIKE (10), TE_SUPERSPIKE (20), TE_WIZSPIKE (colour 20, 30),
TE_KNIGHTSPIKE (226, 20) and the enforcer laser's TE_GUNSHOT; Q2
TE_BLASTER (CL_BlasterParticles)."""
def missile_impact_particles(world: World, game: str, effect: str, origin: Vec3, normal: Vec3) {
    field = particle_field(world, game);
    if game == "q1" {
        looks = {
            "q1_nail": (0, 10),
            "q1_supernail": (0, 20),
            "q1_wizspike": (20, 30),
            "q1_knightspike": (226, 20),
            "q1_laser": (0, 20)
        };
        if effect in looks {
            look = looks[effect];
            quake_particle_effect(field, origin, Vec3(), look[0], look[1]);
        }
    } elif game == "q2" and effect in ["q2_bolt", "q2_hyperbolt"] {
        quake2_blaster_particles(field, origin, normal);
    }
}

"""The arrival flash of a teleport: Q1 TE_TELEPORT (R_TeleportSplash), Q2
EV_PLAYER_TELEPORT (CL_TeleportParticles); elsewhere a brief spray."""
def teleport_splash(world: World, origin: Vec3) {
    field = particle_field(world);
    if field.game == "q1" {
        quake_teleport_splash(field, origin);
    } elif field.game == "q2" {
        quake2_teleport_particles(field, origin);
    } else {
        spark_spray(field, origin, Vec3(z=1.0), 13421772, 24);
    }
}

"""A scorch or bullet hole on a wall (Q3 cg_marks.c CG_ImpactMark): the mark
shader's square, `radius` from its centre, turned by `angle` on the surface
facing `normal`, cut into the `fragments` of the world's faces it lies on
(R_MarkFragments). Marks stay MARK_TOTAL_TIME and fade over the last
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
        age: float = 0.0,
        fragments: list[list[Vec3]] = [];
}

glob MARK_TOTAL_TIME: float = 10.0;
glob MARK_FADE_TIME: float = 1.0;
# cg_marks.c MAX_MARK_POLYS: the oldest marks give way when the pool is full.
glob MAX_MARK_POLYS: int = 256;

"""The world's surfaces marks are laid on. A level supplies them
(R_MarkFragments over its faces); without one a mark is its own square."""
node MarkSurfaces {
    """The pieces of the polygon `points` projected along `projection` onto
    the surfaces behind it, each a polygon of its own."""
    def fragments(points: list[Vec3], projection: Vec3) -> list[list[Vec3]] {
        return [points];
    }
}

edge HasMarkSurfaces: World --> MarkSurfaces {}

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

"""CG_ImpactMark: the mark's square turned at random on the surface, cut by
the world's surfaces 20 units behind it (CM_MarkFragments); a mark that
lands on nothing is not left. The oldest marks give way while the pool of
polygons (MAX_MARK_POLYS) is full."""
def impact_mark(
    world: World,
    shader: str,
    origin: Vec3,
    normal: Vec3,
    radius: float,
    color: Vec3 = Vec3(x=1.0, y=1.0, z=1.0),
    alpha_fade: bool = False
) {
    angle = impact_roll(origin, 3.0) * 2.0 * math.pi;
    facing = normal.normalized();
    axes = mark_axes(facing, angle);
    square = [
        origin.sub(axes[1].scale(radius)).sub(axes[0].scale(radius)),
        origin.add(axes[1].scale(radius)).sub(axes[0].scale(radius)),
        origin.add(axes[1].scale(radius)).add(axes[0].scale(radius)),
        origin.sub(axes[1].scale(radius)).add(axes[0].scale(radius))
    ];
    fragments = [square];
    for surfaces in [world->:HasMarkSurfaces:->][?:MarkSurfaces] {
        fragments = surfaces.fragments(square, facing.scale(-20.0));
    }
    if not fragments {
        return;
    }
    marks = [world->:HasMark:->][?:ImpactMark];
    polys = sum([len(mark.fragments) for mark in marks]);
    while marks and polys + len(fragments) > MAX_MARK_POLYS {
        oldest = marks[0];
        for mark in marks {
            if mark.age > oldest.age {
                oldest = mark;
            }
        }
        polys -= len(oldest.fragments);
        marks.remove(oldest);
        world del --> oldest;
    }
    world +>:HasMark:+> ImpactMark(
        pos=origin.add(Vec3()),
        normal=facing,
        shader=shader,
        radius=radius,
        angle=angle,
        color=color,
        alpha_fade=alpha_fade,
        fragments=fragments
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
ricochets, the lightning gun hits, the rocket, grenade and BFG explode
with sfx_rockexp and the plasma and rail with sfx_plasmaexp; the shotgun
is silent). `roll` stands for rand()&3 in Q3."""
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
        return "sound/weapons/lashit.wav" if weapon in ["q2_bolt", "q2_hyperbolt"] else "";
    }
    if game == "q3" {
        pick = int(roll * 4.0);
        if weapon == "machinegun" {
            return "sound/weapons/machinegun/ric" + ("1" if pick == 0 else ("2" if pick == 1 else "3")) + ".wav";
        }
        if weapon == "lightning" {
            return "sound/weapons/lightning/lg_hit" + ("2" if pick < 2 else ("" if pick == 2 else "3")) + ".wav";
        }
        if weapon in ["q3_rocket", "q3_grenade", "q3_bfg"] {
            return "sound/weapons/rocket/rocklx1a.wav";
        }
        if weapon in ["q3_plasma", "railgun"] {
            return "sound/weapons/plasma/plasmx1a.wav";
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
ricochet sound and a missile's own impact particles, or in Q3 the whole of
CG_MissileHitWall (quake3_missile_hit_wall). `surface` is
CollisionMap.surface_class: the sky takes nothing, SURF_NOMARKS no mark.
`model` is the brush model struck; movers take no marks, as Q3 marks only
the world."""
def wall_impact(
    world: World,
    game: str,
    weapon: str,
    origin: Vec3,
    normal: Vec3,
    surface: int = 0,
    model: int = 0
) {
    if surface >= 2 {
        return;
    }
    if game == "q3" {
        quake3_missile_hit_wall(world, weapon, origin, normal, surface == 0 and model <= 0);
        return;
    }
    impact_sound(world, origin, ricochet_sound(game, weapon, impact_roll(origin)));
    missile_impact_particles(world, game, weapon, origin, normal);
}

"""Q3 CG_MissileHitWall's explosion for each weapon (cg_weapons.c; with
cg_oldRocket's default of 1 the rocket adds no particle explosion): the
effect it is drawn as (a model under a shader, or a shader sprite 16 units
out from the wall), how long it lasts, and its dynamic light and colour."""
obj Quake3Blast {
    has kind: str = "",
        sprite: bool = False,
        duration: float = 0.6,
        light: float = 0.0,
        light_color: Vec3 = Vec3(x=1.0, y=1.0);
}

def quake3_blast(weapon: str) -> Quake3Blast {
    if weapon in ["machinegun", "shotgun"] {
        return Quake3Blast(kind="q3_bullet_explosion");
    }
    if weapon == "q3_plasma" {
        return Quake3Blast(kind="q3_plasma_explosion");
    }
    if weapon == "railgun" {
        return Quake3Blast(kind="q3_rail_explosion");
    }
    if weapon == "q3_grenade" {
        return Quake3Blast(kind="q3_grenade_explosion", sprite=True, light=300.0);
    }
    if weapon == "q3_rocket" {
        return Quake3Blast(
            kind="q3_rocket_explosion", sprite=True, duration=1.0, light=300.0, light_color=Vec3(x=1.0, y=0.75)
        );
    }
    if weapon == "q3_bfg" {
        return Quake3Blast(kind="q3_bfg_explosion", sprite=True);
    }
    # The lightning gun's hit is drawn with its beam.
    return Quake3Blast();
}

# cg_localents.c MAX_LOCAL_ENTITIES: the oldest local entity gives way.
glob QUAKE3_LOCAL_ENTITIES: int = 512;

"""A Q3 local entity for an explosion (cg_effects.c CG_MakeExplosion, or
CG_Bleed's): its time skewed back by rand()&63 ms so bursts are not in
step, turned rand()%360 degrees (a sprite about the view, a model about
`direction`)."""
def quake3_local_explosion(
    world: World,
    kind: str,
    origin: Vec3,
    direction: Vec3,
    duration: float,
    skew: bool = True,
    light: float = 0.0,
    light_color: Vec3 = Vec3()
) {
    blasts = [world->:HasExplosion:->][?:Explosion];
    if len(blasts) >= QUAKE3_LOCAL_ENTITIES {
        oldest = blasts[0];
        for blast in blasts {
            if blast.lifetime - blast.age < oldest.lifetime - oldest.age {
                oldest = blast;
            }
        }
        world del --> oldest;
    }
    world +>:HasExplosion:+> Explosion(
        pos=origin.add(Vec3()),
        kind=kind,
        lifetime=duration,
        age=float(int(impact_roll(origin, 5.0) * 64.0)) / 1000.0 if skew else 0.0,
        light=light_color,
        light_radius=light,
        direction=direction.normalized(),
        rotation=float(int(impact_roll(origin, 7.0) * 360.0))
    );
}

"""Q3 CG_MissileHitWall: a shot of `weapon` striking the world at `origin`
facing `direction`: its sound, its explosion (CG_MakeExplosion: a sprite
explosion sits 16 units out from the wall) and, when `marked`, its mark
(CG_ImpactMark; the rail's in its colour)."""
def quake3_missile_hit_wall(world: World, weapon: str, origin: Vec3, direction: Vec3, marked: bool = True) {
    impact_sound(world, origin, ricochet_sound("q3", weapon, impact_roll(origin)));
    blast = quake3_blast(weapon);
    if blast.kind {
        at = origin.add(direction.normalized().scale(16.0)) if blast.sprite else origin;
        quake3_local_explosion(world, blast.kind, at, direction, blast.duration, light=blast.light, light_color=blast.light_color);
    }
    look = mark_look("q3", weapon);
    if look.shader and marked {
        impact_mark(
            world,
            look.shader,
            origin,
            direction,
            look.radius,
            RAIL_MARK_COLOR if weapon == "railgun" else Vec3(x=1.0, y=1.0, z=1.0),
            look.alpha_fade
        );
    }
}

"""Q3 CG_MissileHitPlayer: blood where a missile strikes someone (not drawn
for the viewer's own body, CG_Bleed's RF_THIRD_PERSON), and for the
grenade and the rocket the explosion of CG_MissileHitWall too."""
def quake3_missile_hit_player(world: World, weapon: str, origin: Vec3, direction: Vec3, viewer: bool = False) {
    if not viewer {
        quake3_bleed(world, origin);
    }
    if weapon in ["q3_grenade", "q3_rocket"] {
        quake3_missile_hit_wall(world, weapon, origin, direction);
    }
}

"""Q3 CG_Bleed: a spurt of blood, the bloodExplosion shader as a sprite 24
units across turned at random, for half a second."""
def quake3_bleed(world: World, origin: Vec3) {
    quake3_local_explosion(world, "q3_blood", origin, Vec3(z=1.0), 0.5, skew=False);
}

"""A missile striking flesh at `origin` facing `direction` (a body, a monster
or a player; `viewer` the one whose eyes the view is): Q3 sends
EV_MISSILE_HIT (CG_MissileHitPlayer); the other games burst as they do
anywhere (explode)."""
def missile_hit_flesh(world: World, game: str, weapon: str, origin: Vec3, direction: Vec3, viewer: bool = False) {
    if game == "q3" {
        quake3_missile_hit_player(world, weapon, origin, direction, viewer);
    }
}

"""How each game's explosion looks and sounds, and its dynamic light: Q1
BecomeExplosion (s_explod.spr, TE_EXPLOSION particles and light, r_exp3.wav),
Q2 CL_ParseTEnt (r_explode model, 350 light, rocket or grenade sound). Q3's
come with the missile's hit (quake3_missile_hit_wall)."""
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
    return BlastLook(lifetime=0.5, sparks=24);
}

"""Which explosion a missile makes on bursting, by game and missile effect;
none in Q3, whose missiles burst through their hit events
(quake3_missile_hit_wall, quake3_missile_hit_player)."""
def blast_kind(game: str, effect: str) -> str {
    if game == "q2" {
        if effect == "q2_bfg" {
            return "";
        }
        return "q2_grenade_explosion" if "grenade" in effect else "q2_explosion";
    }
    if game == "q3" {
        return "";
    }
    return "q1_explosion" if game == "q1" else "blast";
}

"""An explosion showing: where, which effect draws it, how long it lasts and
how far in, its light and sound, a variant (Q2's starting frame), and for
Q3 the direction it faces and its turn in degrees."""
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
        variant: int = 0,
        direction: Vec3 = Vec3(z=1.0),
        rotation: float = 0.0;
}

"""Start an explosion at `origin`: its look, light and sound, and its burst of
particles (Q1 TE_EXPLOSION's R_ParticleExplosion, Q2 CL_ExplosionParticles)."""
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
    field = particle_field(world);
    if kind == "q1_explosion" {
        quake_particle_explosion(field, origin);
    } elif kind.startswith("q2_") {
        quake2_explosion_particles(field, origin);
    } elif look.sparks > 0 {
        spark_spray(field, origin, Vec3(z=1.0), 16756800, look.sparks);
    }
}

walker ParticleTick {
    has dt: float,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        visit [here->:HasParticles:->];
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

    """The particle clock runs with the world; spent puffs go (particles are
    spawn records the renderer keeps until they die)."""
    can advance with ParticleField entry {
        here.clock += self.dt;
        if here.puffs and here.puffs[0].born + here.puffs[0].life < here.clock {
            here.puffs = [puff for puff in here.puffs if puff.born + puff.life >= here.clock];
        }
    }
}
