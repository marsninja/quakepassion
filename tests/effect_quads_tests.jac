"""The effect scene's instanced quads and its one walk over a world's effects."""
import struct;
import from engine.render.effects {
    EffectQuads,
    EffectScene,
    UploadedSprite,
    GatherEffects,
    BALLOON_SHADER,
    EFFECT_STRIDE,
    EFFECT_BLEND_ALPHA,
    EFFECT_BLEND_ADD,
    EFFECT_BLEND_DARKEN,
    effect_byte
}
import from engine.world.world { World }
import from engine.world.particle_field { particle_field }
import from engine.world.particles {
    ImpactMark,
    HasMark,
    ShotTrail,
    HasTrail,
    Explosion,
    HasExplosion
}
import from engine.world.combat { Projectile, HasProjectile, Opponent, HasOpponent }
import from engine.formats.sprite { SpriteFrame }
import from engine.math.interpolation { TickBlend }
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

test "effects are gathered in one walk with the particle field" {
    world = World();
    field = particle_field(world, "q1");
    world +>:HasMark:+> ImpactMark(pos=Vec3(), normal=Vec3(z=1.0), shader="gfx/damage/bullet_mrk", radius=8.0);
    world +>:HasTrail:+> ShotTrail(start=Vec3(), finish=Vec3(x=64.0));
    world +>:HasExplosion:+> Explosion(pos=Vec3(), kind="q1_explosion");
    world +>:HasProjectile:+> Projectile(pos=Vec3(), velocity=Vec3(), damage=0, effect="q3_plasma");
    found = world spawn GatherEffects();
    assert found.field is field;
    assert len(found.marks) == 1 and len(found.trails) == 1;
    assert len(found.blasts) == 1 and len(found.projectiles) == 1;
}

test "a bot typing a chat line wears the talk balloon over its head" {
    world = World();
    typing = Opponent(arena=True, health=100, pos=Vec3(x=10.0, z=26.0), eye_height=26.0);
    typing.visual.visible = True;
    typing.bot_state.talking = True;
    idle = Opponent(arena=True, health=100, pos=Vec3(x=90.0, z=26.0), eye_height=26.0);
    idle.visual.visible = True;
    world +>:HasOpponent:+> typing;
    world +>:HasOpponent:+> idle;
    # Without the balloon's art the players are not looked at.
    assert not (world spawn GatherEffects()).talkers;
    found = world spawn GatherEffects(balloons=True);
    assert found.talkers == [typing];
    # CG_PlayerFloatSprite: 48 over the origin, 10 units in radius.
    scene = EffectScene();
    scene.flight[BALLOON_SHADER] = [
        UploadedSprite(frame=SpriteFrame(width=32, height=32, origin_x=16, origin_y=16, image=BALLOON_SHADER), texture=7)
    ];
    assert scene.add_balloons(found.talkers, TickBlend());
    assert scene.quads.count == 1 and scene.quads.runs[0].texture == 7 and scene.quads.runs[0].blend == EFFECT_BLEND_ALPHA;
    record = struct.unpack_from("<17f4Bf", scene.quads.packed, 0);
    assert record[0] == 10.0 and record[2] == 48.0;
    assert abs(record[9] + 10.0) < 0.001 and abs(record[11] - 10.0) < 0.001;
    assert not EffectScene().add_balloons(found.talkers, TickBlend());
}
