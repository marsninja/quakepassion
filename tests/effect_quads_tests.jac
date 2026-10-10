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
    EffectCvars,
    Awarded,
    AWARD_SHADERS,
    rail_core_ends,
    rail_rings,
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
import from engine.world.arena { ArenaMatch, HasMatch, Competes, MatchTick, credit_impressive, show_award, REWARD_SPRITE_TIME }
import from engine.world.world { Player }
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

test "the rail is its core alone by default, lowered as CG_RailTrail lowers it" {
    cvars = EffectCvars();
    assert cvars.old_rail.on() and cvars.rail_time.number == 400.0;
    start = Vec3(x=10.0, y=20.0, z=30.0);
    finish = Vec3(x=510.0, y=20.0, z=30.0);
    # start[2] -= 4, then cg_oldRail nudges both ends down 8.
    ends = rail_core_ends(start, finish, True);
    assert ends[0].z == 18.0 and ends[1].z == 22.0 and ends[0].x == 10.0 and ends[1].x == 510.0;
    # With the spiral the core is not nudged.
    plain = rail_core_ends(start, finish, False);
    assert plain[0].z == 26.0 and plain[1].z == 30.0;
}

test "the rail's spiral leaves a ring every other step, turning 20 degrees, drifting outward" {
    start = Vec3(z=4.0);
    finish = Vec3(x=100.0);
    rings = rail_rings(start, finish, 0.0);
    # A 100-unit beam: steps 0, 5 ... 95 leave rings at 0, 10 ... 90.
    assert len(rings) == 10;
    # The first sits 20 units along the lowered beam, 4 off its axis.
    assert abs(rings[0].pos.x - 20.0) < 0.0001;
    assert abs(Vec3(y=rings[0].pos.y, z=rings[0].pos.z).length() - 4.0) < 0.0001;
    for i in range(9) {
        a = Vec3(y=rings[i].pos.y, z=rings[i].pos.z);
        b = Vec3(y=rings[i + 1].pos.y, z=rings[i + 1].pos.z);
        assert abs(rings[i + 1].pos.x - rings[i].pos.x - 10.0) < 0.0001;
        # Two 10-degree steps between rings.
        assert abs(a.normalized().dot(b.normalized()) - 0.9396926) < 0.0001;
    }
    # TR_LINEAR at 6 units a second along its perpendicular.
    later = rail_rings(start, finish, 0.5);
    assert abs(Vec3(y=later[0].pos.y, z=later[0].pos.z).length() - 7.0) < 0.0001;
    assert later[0].pos.x == rings[0].pos.x;
    # A ring lives 600 ms plus half its step in milliseconds: the ring of
    # step 90 goes at 645 ms, the first at 600.
    assert len(rail_rings(start, finish, 0.599)) == 10;
    assert len(rail_rings(start, finish, 0.601)) == 9;
    assert len(rail_rings(start, finish, 0.644)) == 1 and len(rail_rings(start, finish, 0.646)) == 0;
    assert not rail_rings(start, start.sub(Vec3(z=4.0)), 0.0);
}

test "an award floats its medal over a bot for two seconds, under a talk balloon" {
    world = World();
    contest = ArenaMatch(fraglimit=20);
    world +>:HasMatch:+> contest;
    human = Player(health=100);
    winner = Opponent(arena=True, health=100, pos=Vec3(x=10.0, z=26.0), eye_height=26.0);
    winner.visual.visible = True;
    loser = Opponent(arena=True, health=100, pos=Vec3(x=90.0, z=26.0), eye_height=26.0);
    loser.visual.visible = True;
    world +>:HasOpponent:+> winner;
    world +>:HasOpponent:+> loser;
    contest +>:Competes:name="You", human=True:+> human;
    contest +>:Competes:name="Sarge":+> winner;
    contest +>:Competes:name="Grunt":+> loser;
    assert not (world spawn GatherEffects(balloons=True)).awarded;
    # A gauntlet frag raises the gauntlet medal over the bot that made it.
    loser.health = 0;
    loser.killer = winner;
    loser.death_means = "gauntlet";
    contest spawn MatchTick(dt=0.1);
    found = world spawn GatherEffects(balloons=True);
    assert [(honour.actor, honour.award) for honour in found.awarded] == [(winner, "gauntlet")];
    # A second frag inside three seconds is Excellent, which replaces it.
    loser.health = 100;
    contest spawn MatchTick(dt=0.5);
    loser.health = 0;
    contest spawn MatchTick(dt=0.1);
    found = world spawn GatherEffects(balloons=True);
    assert found.awarded[0].award == "excellent" and REWARD_SPRITE_TIME == 2.0;
    # CG_PlayerFloatSprite: the medal 48 over the origin, 10 units in radius.
    scene = EffectScene();
    scene.flight[AWARD_SHADERS["excellent"]] = [
        UploadedSprite(frame=SpriteFrame(width=64, height=64, origin_x=32, origin_y=32, image="medal"), texture=9)
    ];
    assert scene.add_awards(found.awarded, TickBlend());
    record = struct.unpack_from("<17f4Bf", scene.quads.packed, 0);
    assert scene.quads.runs[0].texture == 9 and record[0] == 10.0 and record[2] == 48.0;
    assert abs(record[9] + 10.0) < 0.001 and abs(record[11] - 10.0) < 0.001;
    assert not EffectScene().add_awards(found.awarded, TickBlend());
    # While it types, the balloon shows instead (CG_PlayerSprites' order).
    winner.bot_state.talking = True;
    typing = world spawn GatherEffects(balloons=True);
    assert typing.talkers == [winner] and not typing.awarded;
    winner.bot_state.talking = False;
    # The human's own medal shows only in third person: an Impressive is
    # kept on its score for the sprite's two seconds, then taken down.
    credit_impressive(contest, human);
    entries = [edge contest->:Competes:->];
    assert entries[0].award == "impressive" and entries[0].impressive == 1;
    assert len((world spawn GatherEffects(balloons=True)).awarded) == 1;
    loser.health = 100;
    contest spawn MatchTick(dt=2.5);
    contest spawn MatchTick(dt=0.1);
    assert entries[0].award == "" and entries[1].award == "";
    assert not (world spawn GatherEffects(balloons=True)).awarded;
}
