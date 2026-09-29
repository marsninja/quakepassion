"""Render-side pieces of the lighting and effects work that need no window:
the rotating Q2 sky, model texture steps, particle records and the
teleporter pad's sparkle."""
import struct;
import from engine.render.quake { sky_turn, packed_tcmods }
import from engine.render.models { MODEL_PLAIN_STEPS }
import from engine.render.particles { pack_particle, PARTICLE_STRIDE }
import from engine.formats.animated { ModelStage, TexMod, ShaderWave }
import from engine.world.particle_field { Particle, particle_field, PARTICLE_QUAKE2 }
import from engine.world.missile_trails { EmitTrails }
import from engine.world.particles { ParticleTick }
import from engine.world.fixtures { Fixture, HasFixture }
import from engine.world.world { World }
import from engine.math.vec3 { Vec3 }

test "a rotating sky turns counter-clockwise about its axis as glRotatef does" {
    turned = sky_turn(Vec3(x=1.0), Vec3(z=4.0), 90.0);
    assert abs(turned.x) < 0.00001 and abs(turned.y - 1.0) < 0.00001 and abs(turned.z) < 0.00001;
    along = sky_turn(Vec3(z=5.0), Vec3(z=1.0), 33.0);
    assert abs(along.z - 5.0) < 0.00001 and abs(along.x) < 0.00001;
}

test "model stages without tcMods take one identity texture step" {
    plain = packed_tcmods(ModelStage(), 3.0);
    assert plain[0] == MODEL_PLAIN_STEPS[0] and plain[1] == MODEL_PLAIN_STEPS[1] and plain[2] == MODEL_PLAIN_STEPS[2];
    # A turb splits the steps: rotate, then the turb, then what follows.
    stage = ModelStage(
        mods=[
            TexMod(kind="rotate", a=30.0),
            TexMod(kind="turb", wave=ShaderWave(amplitude=0.2, frequency=1.0)),
            TexMod(kind="scroll", a=1.0, b=0.1)
        ]
    );
    steps = packed_tcmods(stage, 1.0);
    assert len(steps[0]) == 32 and len(steps[2]) == 32;
    turb = struct.unpack("<4f", steps[2][0:16]);
    assert turb[0] == 1.0 and abs(turb[1] - 0.2) < 0.00001 and abs(turb[2] - 1.0) < 0.00001;
    scroll = struct.unpack("<4f", steps[0][16:32]);
    assert abs(scroll[2] - 1.0) < 0.00001;
}

test "particle records pack as the particle shader reads them" {
    out = bytearray(PARTICLE_STRIDE);
    particle = Particle(
        origin=Vec3(x=1.0, y=2.0, z=3.0),
        velocity=Vec3(x=4.0),
        accel=Vec3(z=-40.0),
        born=5.0,
        life=0.5,
        kind=PARTICLE_QUAKE2,
        color=224,
        alpha=1.0,
        fade=-2.0
    );
    pack_particle(out, 0, particle);
    values = struct.unpack("<16f", bytes(out));
    assert values[0:3] == (1.0, 2.0, 3.0) and values[3] == 4.0 and values[8] == -40.0;
    assert values[9] == 5.0 and values[10] == 0.5 and values[12] == float(PARTICLE_QUAKE2);
    assert values[13] == 224.0 and values[14] == 1.0 and values[15] == -2.0;
}

test "a teleporter pad sparkles eight green specks a client frame" {
    world = World();
    field = particle_field(world, "q2");
    pad = Fixture(pos=Vec3(x=64.0, z=16.0), effect="teleporter");
    world +>:HasFixture:+> pad;
    world spawn EmitTrails();
    assert len(field.fresh) == 8;
    # A frame drawn again at the same effect time is the same client frame.
    world spawn EmitTrails();
    assert len(field.fresh) == 8;
    # However far the clock moved, one drawn frame is one client frame.
    world spawn ParticleTick(dt=0.1);
    world spawn EmitTrails();
    assert len(field.fresh) == 16;
    for speck in field.fresh {
        assert speck.color == 219 and speck.velocity.z >= 80.0 and abs(speck.origin.x - 64.0) <= 16.0;
    }
    # Other fixtures sparkle nothing.
    world +>:HasFixture:+> Fixture(pos=Vec3());
    field.fresh = [];
    world spawn EmitTrails();
    assert not field.fresh;
}
