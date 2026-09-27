import struct;
import from engine.render.effects {
    EffectQuads,
    GatherEffects,
    EFFECT_STRIDE,
    EFFECT_BLEND_ALPHA,
    EFFECT_BLEND_ADD,
    EFFECT_BLEND_DARKEN,
    effect_byte
}
import from engine.world.world { World }
import from engine.world.particles {
    ImpactParticle,
    HasParticle,
    ImpactMark,
    HasMark,
    ShotTrail,
    HasTrail,
    Explosion,
    HasExplosion
}
import from engine.world.combat { Projectile, HasProjectile }
import from engine.math.vec3 { Vec3 }

def quad(queue: EffectQuads, texture: int, blend: int, x: float) {
    queue.add(
        texture, blend, Vec3(x=x, y=2.0, z=3.0), Vec3(), Vec3(z=1.0),
        -1.0, -2.0, 3.0, 4.0, 0.0, 1.0, 1.0, 0.0, 255, 128, 0, 64, 0.5
    );
}

test "effect quads pack one record per quad and split runs on texture or blend" {
    queue = EffectQuads();
    quad(queue, 7, EFFECT_BLEND_ADD, 1.0);
    quad(queue, 7, EFFECT_BLEND_ADD, 2.0);
    quad(queue, 7, EFFECT_BLEND_ALPHA, 3.0);
    quad(queue, 9, EFFECT_BLEND_ALPHA, 4.0);
    quad(queue, 9, EFFECT_BLEND_DARKEN, 5.0);
    assert queue.count == 5;
    assert [run.first for run in queue.runs] == [0, 2, 3, 4];
    assert [run.count for run in queue.runs] == [2, 1, 1, 1];
    assert [run.texture for run in queue.runs] == [7, 7, 9, 9];
    record = struct.unpack_from("<17f4Bf", queue.packed, EFFECT_STRIDE);
    assert record[0] == 2.0 and record[1] == 2.0 and record[2] == 3.0;
    # A zero axis faces the camera; the second axis is carried as given.
    assert record[3] == 0.0 and record[8] == 1.0;
    assert record[9] == -1.0 and record[10] == -2.0 and record[11] == 3.0 and record[12] == 4.0;
    assert record[13] == 0.0 and record[14] == 1.0 and record[15] == 1.0 and record[16] == 0.0;
    assert record[17] == 255 and record[18] == 128 and record[19] == 0 and record[20] == 64;
    assert record[21] == 0.5;
}

test "effect quads grow their packed records past the first capacity" {
    queue = EffectQuads();
    for i in range(1500) {
        quad(queue, 3, EFFECT_BLEND_ADD, float(i));
    }
    assert queue.count == 1500;
    assert len(queue.packed) >= 1500 * EFFECT_STRIDE;
    assert len(queue.runs) == 1 and queue.runs[0].count == 1500;
    record = struct.unpack_from("<17f4Bf", queue.packed, 1499 * EFFECT_STRIDE);
    assert record[0] == 1499.0;
}

test "effect bytes clamp colour channels as the immediate-mode tint did" {
    assert effect_byte(-0.5) == 0;
    assert effect_byte(0.5) == 127;
    assert effect_byte(2.0) == 255;
}

test "effects are gathered in one walk, particles apart from sprites" {
    world = World();
    world +>:HasParticle:+> ImpactParticle(pos=Vec3(), velocity=Vec3());
    world +>:HasParticle:+> ImpactParticle(pos=Vec3(x=1.0), velocity=Vec3());
    world +>:HasMark:+> ImpactMark(pos=Vec3(), normal=Vec3(z=1.0), shader="gfx/damage/bullet_mrk", radius=8.0);
    world +>:HasTrail:+> ShotTrail(start=Vec3(), finish=Vec3(x=64.0));
    world +>:HasExplosion:+> Explosion(pos=Vec3(), kind="q1_explosion");
    world +>:HasProjectile:+> Projectile(pos=Vec3(), velocity=Vec3(), damage=0, effect="q3_plasma");
    sprites = world spawn GatherEffects(with_particles=False);
    assert len(sprites.particles) == 0;
    assert len(sprites.marks) == 1 and len(sprites.trails) == 1;
    assert len(sprites.blasts) == 1 and len(sprites.projectiles) == 1;
    specks = world spawn GatherEffects(with_sprites=False);
    assert len(specks.particles) == 2 and not specks.marks and not specks.projectiles;
}
