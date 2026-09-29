"""Particles, trails, puffs and dynamic lights as the original clients make
them (r_part.c, cl_fx.c, cg_weapons.c, cl_main.c, cl_tent.c)."""
import math;
import from engine.world.world { World, Player }
import from engine.world.combat { Projectile, HasProjectile, CombatState }
import from engine.world.particles { Explosion, HasExplosion, ParticleTick, explode, impact_spray, wall_impact, blast_kind }
import from engine.world.particle_field {
    Particle,
    Puff,
    particle_field,
    particle_state,
    puff_state,
    quake_rocket_trail,
    quake_particle_explosion,
    quake2_diminishing_trail,
    quake2_particle,
    quake2_bfg_particles,
    quake3_smoke_trail,
    quake_trail_kind,
    PARTICLE_FIRE,
    PARTICLE_EXPLODE,
    PARTICLE_EXPLODE2,
    PARTICLE_BLOB2,
    PARTICLE_GRAV,
    PARTICLE_STATIC,
    PARTICLE_SLOWGRAV,
    PARTICLE_QUAKE2,
    QUAKE_RAMP1,
    QUAKE_RAMP3
}
import from engine.world.missile_trails { EmitTrails }
import from engine.world.light_effects { combat_lights, explosion_light, missile_light, DYNAMIC_LIGHT_LIMIT }
import from engine.world.lighting { Lighting }
import from engine.math.vec3 { Vec3 }
import from engine.formats.anorms { quake_vertex_normal }

test "Q1 rocket trails drop fire every 3 units that rises and burns through ramp3" {
    world = World();
    field = particle_field(world, "q1");
    quake_rocket_trail(field, Vec3(), Vec3(x=30.0), 0);
    assert len(field.fresh) == 10;
    for particle in field.fresh {
        assert particle.kind == PARTICLE_FIRE and particle.life == 2.0 and 0.0 <= particle.ramp < 4.0;
        assert abs(particle.origin.y) <= 3.0;
    }
    first = field.fresh[0];
    # Ramp 5 a second: the colour steps through ramp3 and dies at 6.
    state = particle_state(first, first.born + 0.2);
    assert state.alive and state.color == QUAKE_RAMP3[int(first.ramp + 1.0)];
    assert state.position.z > first.origin.z;
    assert not particle_state(first, first.born + (6.0 - first.ramp) / 5.0 + 0.01).alive;
    # Grenade smoke starts two steps further along the ramp.
    field.fresh = [];
    quake_rocket_trail(field, Vec3(), Vec3(x=9.0), 1);
    assert len(field.fresh) == 3 and all([p.ramp >= 2.0 for p in field.fresh]);
}

test "Q1 tracers alternate sideways and slight blood skips ahead" {
    field = particle_field(World(), "q1");
    quake_rocket_trail(field, Vec3(), Vec3(x=9.0), 3);
    assert len(field.fresh) == 3 and field.tracers == 3;
    assert field.fresh[0].velocity.y == -30.0 and field.fresh[1].velocity.y == 30.0;
    assert field.fresh[0].life == 0.5 and field.fresh[0].kind == PARTICLE_STATIC;
    # Wizard tracers are colour 52 or 60, hell knight ones 230 or 238.
    assert field.fresh[0].color in [52, 60];
    field.fresh = [];
    quake_rocket_trail(field, Vec3(), Vec3(x=24.0), 4);
    assert len(field.fresh) == 4 and field.fresh[0].kind == PARTICLE_GRAV;
    # Model flags pick the trail in CL_RelinkEntities' order.
    assert quake_trail_kind(4) == 2 and quake_trail_kind(1) == 0 and quake_trail_kind(2) == 1;
    assert quake_trail_kind(16) == 3 and quake_trail_kind(64) == 5 and quake_trail_kind(128) == 6;
    assert quake_trail_kind(32) == 4 and quake_trail_kind(8) == -1;
}

test "closed-form Q1 motion matches R_DrawParticles' per-frame steps" {
    for kind in [PARTICLE_EXPLODE, PARTICLE_EXPLODE2, PARTICLE_BLOB2, PARTICLE_FIRE, PARTICLE_GRAV] {
        particle = Particle(origin=Vec3(), velocity=Vec3(x=100.0, y=-50.0, z=80.0), life=5.0, kind=kind);
        position = Vec3();
        velocity = particle.velocity;
        step = 0.0005;
        t = 0.0;
        while t < 0.4 {
            position = position.add(velocity.scale(step));
            grav = step * 40.0;
            if kind == PARTICLE_EXPLODE {
                velocity = velocity.add(velocity.scale(4.0 * step));
                velocity = Vec3(x=velocity.x, y=velocity.y, z=velocity.z - grav);
            } elif kind == PARTICLE_EXPLODE2 {
                velocity = velocity.sub(velocity.scale(step));
                velocity = Vec3(x=velocity.x, y=velocity.y, z=velocity.z - grav);
            } elif kind == PARTICLE_BLOB2 {
                velocity = Vec3(x=velocity.x - velocity.x * 4.0 * step, y=velocity.y - velocity.y * 4.0 * step, z=velocity.z - grav);
            } elif kind == PARTICLE_FIRE {
                velocity = Vec3(x=velocity.x, y=velocity.y, z=velocity.z + grav);
            } else {
                velocity = Vec3(x=velocity.x, y=velocity.y, z=velocity.z - grav);
            }
            t += step;
        }
        state = particle_state(particle, t);
        assert state.alive or kind in [PARTICLE_FIRE];
        if state.alive {
            assert state.position.sub(position).length() < 0.5;
        }
    }
    # Explosions run ramp1 at 10 steps a second and end at 8.
    burst = Particle(origin=Vec3(), life=5.0, kind=PARTICLE_EXPLODE, ramp=1.0);
    assert particle_state(burst, 0.15).color == QUAKE_RAMP1[2];
    assert not particle_state(burst, 0.71).alive;
}

test "Q2 particles fall as org + vel t + accel t^2 and fade by alphavel" {
    field = particle_field(World(), "q2");
    speck = quake2_particle(field, Vec3(), Vec3(x=10.0), Vec3(z=-40.0), 224, -2.0);
    assert speck.kind == PARTICLE_QUAKE2 and speck.life == 0.5;
    state = particle_state(speck, 0.25);
    assert abs(state.position.x - 2.5) < 0.0001 and abs(state.position.z + 2.5) < 0.0001;
    assert abs(state.alpha - 0.5) < 0.0001 and state.color == 224;
    assert not particle_state(speck, 0.6).alive;
    # The diminishing trail thins: its count drops 5 a half unit, to 100.
    count = quake2_diminishing_trail(field, Vec3(), Vec3(x=10.0), 1024, True);
    assert count == 1024 - 5 * 20;
    assert quake2_diminishing_trail(field, Vec3(), Vec3(x=1000.0), count, True) == 100;
    # Gib blood is 0xe8-0xef and drops at PARTICLE_GRAVITY from the start.
    assert all([232 <= p.color <= 239 for p in field.fresh]);
}

test "Q3 smoke puffs follow the missile every 50 ms, growing and fading" {
    field = particle_field(World(), "q3");
    quake3_smoke_trail(field, Vec3(), Vec3(x=100.0), 0.0, 0.2, 64.0, 2.0);
    assert [round(puff.born, 3) for puff in field.puffs] == [0.05, 0.1, 0.15, 0.2];
    assert abs(field.puffs[1].origin.x - 50.0) < 0.001 and field.puffs[0].shader == "smokePuff";
    puff = field.puffs[0];
    state = puff_state(puff, puff.born + 1.0, Vec3(x=1000.0));
    # Half its life: 8 + half the radius, a third opaque times half.
    assert abs(state.radius - 40.0) < 0.001 and abs(state.alpha - 0.165) < 0.001;
    # Gone once the eye is inside it.
    assert not puff_state(puff, puff.born + 1.0, puff.origin).alive;
    assert not puff_state(puff, puff.born + 2.1, Vec3(x=1000.0)).alive;
}

test "missiles lay their trails as they move, from where they first showed" {
    world = World();
    field = particle_field(world, "q1");
    rocket = Projectile(pos=Vec3(), velocity=Vec3(x=1000.0), damage=100, effect="q1_rocket");
    world +>:HasProjectile:+> rocket;
    world spawn EmitTrails();
    assert not field.fresh;
    rocket.pos = Vec3(x=30.0);
    world spawn EmitTrails();
    assert len(field.fresh) == 10;
    # Nails carry no trail.
    world +>:HasProjectile:+> Projectile(pos=Vec3(), velocity=Vec3(x=1000.0), damage=9, effect="q1_nail");
    field.fresh = [];
    world spawn EmitTrails();
    rocket.pos = Vec3(x=33.0);
    world spawn EmitTrails();
    assert len(field.fresh) == 1;
}

test "the flying BFG ball wears CL_BfgParticles' sphere, laid anew each client frame" {
    world = World();
    field = particle_field(world, "q2");
    field.clock = 2.5;
    quake2_bfg_particles(field, Vec3(x=100.0));
    assert len(field.fresh) == 162 and len(field.avelocities) == 486;
    assert all([0.0 <= spin <= 2.55 for spin in field.avelocities]);
    for i in [0, 57, 161] {
        speck = field.fresh[i];
        spins = field.avelocities[i * 3:i * 3 + 3];
        yaw = 2.5 * spins[0];
        pitch = 2.5 * spins[1];
        forward = Vec3(x=math.cos(pitch) * math.cos(yaw), y=math.cos(pitch) * math.sin(yaw), z=-math.sin(pitch));
        offset = quake_vertex_normal(i).scale(math.sin(2.5 + float(i)) * 64.0).add(forward.scale(16.0));
        assert speck.origin.sub(Vec3(x=100.0).add(offset)).length() < 0.001;
        dist = offset.length() / 90.0;
        assert speck.color == int(math.floor(208.0 + dist * 7.0));
        assert abs(speck.alpha - (1.0 - dist)) < 0.00001 and speck.fade == -100.0;
        assert speck.velocity.length() == 0.0 and speck.kind == PARTICLE_QUAKE2;
    }
    # The spin rates are rolled once; each client frame lays a fresh sphere.
    spins = list(field.avelocities);
    ball = Projectile(pos=Vec3(), velocity=Vec3(x=400.0), damage=200, effect="q2_bfg");
    world +>:HasProjectile:+> ball;
    field.fresh = [];
    world spawn EmitTrails();
    assert len(field.fresh) == 162;
    world spawn EmitTrails();
    assert len(field.fresh) == 162;
    world spawn ParticleTick(dt=1.0 / 120.0);
    world spawn EmitTrails();
    assert len(field.fresh) == 324 and field.avelocities == spins;
    # Bursting, it lays none.
    ball.phase = 1;
    world spawn ParticleTick(dt=1.0 / 120.0);
    world spawn EmitTrails();
    assert len(field.fresh) == 324;
}

test "explosions burst as each game does and impacts spray their counts" {
    world = World();
    field = particle_field(world, "q1");
    explode(world, Vec3(), "q1_explosion");
    assert len(field.fresh) == 1024;
    kinds = set([p.kind for p in field.fresh]);
    assert kinds == set([PARTICLE_EXPLODE, PARTICLE_EXPLODE2]);
    field.fresh = [];
    impact_spray(world, Vec3(), Vec3(x=1.0));
    assert len(field.fresh) == 20 and all([p.color < 8 for p in field.fresh]);
    field.fresh = [];
    impact_spray(world, Vec3(), Vec3(x=1.0), True);
    assert len(field.fresh) == 8 and all([72 <= p.color <= 79 for p in field.fresh]);
    # Chthon's TE_LAVASPLASH: R_LavaSplash's 32 by 32 specks, and nothing else.
    field.fresh = [];
    before = len([world->:HasExplosion:->]);
    explode(world, Vec3(z=-64.0), "q1_lavasplash");
    assert len(field.fresh) == 1024 and len([world->:HasExplosion:->]) == before;
    assert all([224 <= p.color <= 231 and p.kind == PARTICLE_SLOWGRAV and p.velocity.z > 0.0 for p in field.fresh]);
    # A wizard spike striking a wall: TE_WIZSPIKE, 30 of colour 20's row.
    field.fresh = [];
    wall_impact(world, "q1", "q1_wizspike", Vec3(), Vec3(x=1.0));
    assert len(field.fresh) == 30 and all([16 <= p.color <= 23 for p in field.fresh]);
    q2 = World();
    q2_field = particle_field(q2, "q2");
    explode(q2, Vec3(), "q2_explosion");
    assert len(q2_field.fresh) == 256;
    q2_field.fresh = [];
    impact_spray(q2, Vec3(), Vec3(x=1.0), True);
    assert len(q2_field.fresh) == 60;
    # Q3 missiles burst through their hit events (impact_tests), with no
    # explosion of their own and no particles.
    assert blast_kind("q3", "q3_rocket") == "";
    q3 = World();
    wall_impact(q3, "q3", "q3_rocket", Vec3(), Vec3(x=1.0));
    assert not particle_field(q3, "q3").fresh;
    # The particle clock runs with the world.
    world spawn ParticleTick(dt=0.25);
    assert field.clock == 0.25;
}

test "dynamic lights follow each game's client" {
    q1 = Explosion(pos=Vec3(), kind="q1_explosion", lifetime=0.6, light=Vec3(x=1.0, y=0.6, z=0.3), light_radius=350.0, age=0.1);
    light = explosion_light(q1, "q1");
    assert light is not None and abs(light.radius - 320.0) < 0.001 and light.color.y == 1.0;
    q1.age = 0.55;
    assert explosion_light(q1, "q1") is None;
    q2 = Explosion(pos=Vec3(), kind="q2_explosion", lifetime=1.4, light=Vec3(x=1.0, y=0.5, z=0.5), light_radius=350.0, age=0.45);
    light = explosion_light(q2, "q2");
    assert light is not None and abs(light.radius - 350.0 * 12.0 / 16.0) < 0.001;
    q3 = Explosion(pos=Vec3(), kind="q3_rocket_explosion", lifetime=1.0, light=Vec3(x=1.0, y=0.75), light_radius=300.0, age=0.4);
    held = explosion_light(q3, "q3");
    assert held is not None and held.radius == 300.0;
    q3.age = 0.75;
    fading = explosion_light(q3, "q3");
    assert fading is not None and abs(fading.radius - 150.0) < 0.001;
    rocket = missile_light(Projectile(pos=Vec3(), velocity=Vec3(), damage=0, effect="q1_rocket"), Vec3());
    assert rocket is not None and rocket.radius == 200.0 and rocket.color.z == 1.0;
    assert missile_light(Projectile(pos=Vec3(), velocity=Vec3(), damage=0, effect="q3_plasma"), Vec3()) is None;
    bolt = missile_light(Projectile(pos=Vec3(), velocity=Vec3(), damage=0, effect="q2_bolt"), Vec3(x=5.0));
    assert bolt is not None and bolt.color.x == 1.0 and bolt.color.y == 1.0 and bolt.color.z == 0.0 and bolt.origin.x == 5.0;
    # Only the eight nearest the viewer are kept.
    world = World();
    for i in range(12) {
        world +>:HasProjectile:+> Projectile(pos=Vec3(x=float(i) * 100.0), velocity=Vec3(), damage=0, effect="q1_rocket");
    }
    lighting = Lighting();
    combat_lights(lighting, world, Player(), CombatState(game="q1"));
    assert len(lighting.dynamic) == DYNAMIC_LIGHT_LIMIT;
    assert max([flash.origin.x for flash in lighting.dynamic]) == 700.0;
}
