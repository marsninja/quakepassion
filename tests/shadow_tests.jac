"""Q3 blob shadows: CG_PlayerShadow's trace and temporary mark."""
import math;
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.body_queue { Corpse, HasCorpse }
import from engine.world.models { PlayerRig }
import from engine.world.powerups { Powerup, Empowered }
import from engine.world.particles { ImpactMark, HasMark }
import from engine.world.shadows { CastShadows, ShadowCut, shadow_caster, shadow_strength, SHADOW_MARK, SHADOW_RADIUS, SHADOW_DISTANCE }
import from engine.render.effects { EffectScene, EffectCvars, UploadedSprite, sight_cone }
import from engine.formats.sprite { SpriteFrame }
import from engine.physics.collision { CollisionMap }
import from engine.math.interpolation { TickBlend }
import from engine.math.vec3 { Vec3 }

"""A floor whose top is at z = 0, stored for the standing player's box as a
level's hulls are."""
def shadow_floor() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-2000.0, y=-2000.0, z=-64.0), Vec3(x=2000.0, y=2000.0, z=0.0), Vec3(),
        collision.hull_mins, collision.hull_maxs
    );
    collision.reindex();
    return collision;
}

"""A bot whose origin is `height` above the floor (its eyes 26 above that)."""
def standing_bot(world: World, x: float, height: float) -> Opponent {
    bot = Opponent(arena=True, health=100, pos=Vec3(x=x, z=height + 26.0), eye_height=26.0);
    bot.visual.visible = True;
    world +>:HasOpponent:+> bot;
    return bot;
}

test "a player on the ground drops a blob shadow that fades with height" {
    world = World();
    collision = shadow_floor();
    standing_bot(world, 0.0, 24.0);
    standing_bot(world, 200.0, 88.0);
    # Further than SHADOW_DISTANCE above the floor: no shadow.
    standing_bot(world, 400.0, 160.0);
    cast = world spawn CastShadows(collision=shadow_caster(collision));
    assert len(cast.marks) == 2;
    near = cast.marks[0];
    assert near.shader == SHADOW_MARK and near.radius == SHADOW_RADIUS and SHADOW_RADIUS == 24.0 and SHADOW_DISTANCE == 128.0;
    # The box's floor (mins z 0) comes to rest on the ground under the player.
    assert abs(near.pos.z) < 0.1 and near.pos.x == 0.0 and near.normal.z > 0.99;
    # Standing, the origin is 24 of the 128 units up: alpha 1 - 24/128.
    assert abs(near.color.x - (1.0 - 24.0 / 128.0)) < 0.01 and near.color.x == near.color.y and near.color.y == near.color.z;
    assert not near.alpha_fade and len(near.fragments) == 1 and len(near.fragments[0]) == 4;
    high = cast.marks[1];
    assert abs(high.pos.x - 200.0) < 0.001 and abs(high.color.x - (1.0 - 88.0 / 128.0)) < 0.01;
    assert shadow_strength(0.25) == 0.75 and shadow_strength(1.5) == 0.0;
    # Temporary marks: nothing is left on the world.
    assert not [world->:HasMark:->][?:ImpactMark];
}

test "the human, bodies and dormant or invisible players" {
    world = World();
    collision = shadow_floor();
    human = Player(health=100, pos=Vec3(y=300.0, z=24.0 + 26.0), yaw=math.pi / 2.0);
    cast = world spawn CastShadows(collision=shadow_caster(collision), player=human, player_height=26.0);
    # The human's own shadow, turned with its yaw.
    assert len(cast.marks) == 1 and abs(cast.marks[0].pos.y - 300.0) < 0.001 and abs(cast.marks[0].angle - math.pi / 2.0) < 0.0001;
    hidden = standing_bot(world, 0.0, 24.0);
    hidden +>:Empowered:+> Powerup(kind="invisibility", remaining=10.0);
    asleep = standing_bot(world, 100.0, 24.0);
    asleep.dormant = True;
    body = Corpse(pos=Vec3(x=-100.0, z=24.0 + 26.0), eye_height=26.0, body=PlayerRig(legs_angles=Vec3(y=90.0)));
    world +>:HasCorpse:+> body;
    cast = world spawn CastShadows(collision=shadow_caster(collision));
    # Only the body left behind: its legs' yaw turns the mark.
    assert len(cast.marks) == 1 and abs(cast.marks[0].pos.x + 100.0) < 0.001;
    assert abs(cast.marks[0].angle - math.pi / 2.0) < 0.0001;
}

test "cg_shadows 1 is the default and the only setting that lays marks" {
    world = World();
    collision = shadow_floor();
    standing_bot(world, 0.0, 24.0);
    scene = EffectScene();
    assert scene.cvars.shadows.integer == 1;
    # Without the markShadow art (Q1, Q2) there is nothing to draw.
    assert not scene.shadow_marks(world, collision, None, TickBlend());
    scene.flight[SHADOW_MARK] = [
        UploadedSprite(frame=SpriteFrame(width=32, height=32, origin_x=16, origin_y=16, image=SHADOW_MARK), texture=5)
    ];
    assert len(scene.shadow_marks(world, collision, None, TickBlend())) == 1;
    assert not scene.shadow_marks(world, None, None, TickBlend());
    for off in ["0", "2", "3"] {
        scene.cvars.shadows.assign(off);
        assert not scene.shadow_marks(world, collision, None, TickBlend());
    }
}

test "a body out of view casts nothing, and one that has not moved is not cut again" {
    world = World();
    collision = shadow_floor();
    ahead = standing_bot(world, 300.0, 24.0);
    behind = standing_bot(world, -300.0, 24.0);
    beside = standing_bot(world, 0.0, 24.0);
    beside.pos = Vec3(x=100.0, y=900.0, z=50.0);
    # A view from above the origin along +x, 90 degrees across, 16:9.
    sight = sight_cone(Vec3(z=60.0), Vec3(x=1.0), 1.0, 0.5625);
    assert not sight.misses(Vec3(x=300.0), 100.0) and sight.misses(Vec3(x=-300.0), 100.0);
    assert sight.misses(Vec3(x=100.0, y=900.0), 100.0);
    # Near the view's edge it is still cast: a ball that reaches into the cone.
    assert not sight.misses(Vec3(x=100.0, y=180.0), 100.0);
    seen = world spawn CastShadows(collision=shadow_caster(collision), sight=sight);
    assert len(seen.marks) == 1 and abs(seen.marks[0].pos.x - 300.0) < 0.001;
    every = world spawn CastShadows(collision=shadow_caster(collision));
    assert len(every.marks) == 3 and len(every.cuts) == 3;
    # Nobody moved: the same polygons, not cut again (a marked list comes back as it went in).
    marked = [ShadowCut(pos=cut.pos, normal=cut.normal, yaw=cut.yaw, fragments=[[Vec3(z=7.0)]]) for cut in every.cuts];
    again = world spawn CastShadows(collision=shadow_caster(collision), kept=marked);
    assert len(again.marks) == 3 and all([mark.fragments[0][0].z == 7.0 for mark in again.marks]);
    # One steps aside or turns: its mark is cut afresh, the others' kept.
    ahead.pos = ahead.pos.add(Vec3(y=8.0));
    behind.yaw = behind.yaw + 0.5;
    moved = world spawn CastShadows(collision=shadow_caster(collision), kept=marked);
    fresh = [mark for mark in moved.marks if len(mark.fragments[0]) == 4];
    assert len(moved.marks) == 3 and len(fresh) == 2;
    # The scene keeps each frame's cuts for the next.
    scene = EffectScene();
    scene.flight[SHADOW_MARK] = [
        UploadedSprite(frame=SpriteFrame(width=32, height=32, origin_x=16, origin_y=16, image=SHADOW_MARK), texture=5)
    ];
    assert len(scene.shadow_marks(world, collision, None, TickBlend())) == 3 and len(scene.shadow_cuts) == 3;
    assert len(scene.shadow_marks(world, collision, None, TickBlend(), sight)) == 1 and len(scene.shadow_cuts) == 1;
}
