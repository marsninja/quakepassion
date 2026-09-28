"""Frames draw bodies between their last two physics ticks: every moving
body keeps its tick-start pose, and a teleport or a body made mid-tick is
drawn where it is."""
import math;
import from engine.math.interpolation { TickPose, TickBlend, lerp_radians }
import from engine.math.orientation { Basis, blend_basis, model_basis }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from engine.world.world { World, Area, Entity, Player, Occupied, move_to_area }
import from engine.world.combat { Projectile, HasProjectile }
import from engine.world.motion { CaptureMotion }
import from engine.world.models { Visual, ModelResource, HasVisual, UsesModel, GatherModels }
import from engine.formats.animated { AnimatedModel }
import from engine.formats.bsp { Face }
import from engine.render.world_mesh { BrushGroup }
import from engine.core.clock { Clock }

test "a body is drawn alpha of the way from its tick-start pose" {
    pose = TickPose();
    pose.capture(Vec3(x=10.0), 0.0, 0.0, 7);
    blend = TickBlend(tick=7, alpha=0.25);
    at = blend.place(pose, Vec3(x=18.0, z=4.0));
    assert abs(at.x - 12.0) < 0.00001 and abs(at.z - 1.0) < 0.00001;
    # A pose from an older tick (the body was made during the last one), or
    # a settled one, shows the body where it is.
    stale = TickBlend(tick=8, alpha=0.25);
    assert stale.place(pose, Vec3(x=18.0)).x == 18.0;
    pose.settle();
    assert blend.place(pose, Vec3(x=18.0)).x == 18.0;
    # The default blend draws everything where it is.
    assert TickBlend().place(TickPose(), Vec3(y=3.0)).y == 3.0;
}

test "a jump of more than 100 units on an axis is a teleport, not a motion" {
    pose = TickPose();
    pose.capture(Vec3(), 0.0, 0.0, 1);
    blend = TickBlend(tick=1, alpha=0.5);
    assert blend.place(pose, Vec3(z=100.0)).z == 50.0;
    assert blend.place(pose, Vec3(z=100.5)).z == 100.5;
    assert blend.place(pose, Vec3(x=-240.0, y=3.0)).x == -240.0;
}

test "the capture copies the position rather than sharing it" {
    body = Entity(pos=Vec3(x=1.0));
    body.tick_pose.capture(body.pos, 0.0, 0.0, 1);
    body.pos.x = 5.0;
    assert body.tick_pose.pos.x == 1.0;
}

test "angles turn the shorter way round" {
    assert abs(lerp_radians(0.1, 0.3, 0.5) - 0.2) < 0.000001;
    # From just short of a half turn to just past it the other way.
    turned = lerp_radians(math.pi - 0.1, -math.pi + 0.1, 0.5);
    assert abs(math.cos(turned) + 1.0) < 0.000001;
    assert lerp_radians(1.0, 7.0, 1.0) == 7.0;
    pose = TickPose();
    pose.capture(Vec3(), 0.2, -0.4, 3);
    blend = TickBlend(tick=3, alpha=0.5);
    assert abs(blend.turn(pose, Vec3(), 0.6) - 0.4) < 0.000001;
    assert abs(blend.tilt(pose, Vec3(), 0.0) + 0.2) < 0.000001;
}

test "a tick boundary captures every entity in an occupied area and every projectile" {
    world = World();
    area = Area(
        name="a",
        bounds=AABB(mins=Vec3(x=-500.0, y=-500.0, z=-500.0), maxs=Vec3(x=500.0, y=500.0, z=500.0))
    );
    empty = Area(name="b", bounds=AABB(mins=Vec3(x=600.0), maxs=Vec3(x=700.0, y=10.0, z=10.0)));
    world ++> area;
    world ++> empty;
    body = Player(pos=Vec3(x=4.0, y=2.0), yaw=1.0, pitch=0.5);
    move_to_area(body, area);
    rocket = Projectile(pos=Vec3(z=40.0), velocity=Vec3(x=900.0), damage=100);
    world +>:HasProjectile:+> rocket;
    world spawn CaptureMotion(tick=12);
    assert body.tick_pose.tick == 12 and body.tick_pose.pos.x == 4.0;
    assert body.tick_pose.yaw == 1.0 and body.tick_pose.pitch == 0.5;
    assert rocket.tick_pose.tick == 12 and rocket.tick_pose.pos.z == 40.0;
    # The tick moves them; frames between draw them between.
    body.pos = Vec3(x=8.0, y=2.0);
    rocket.pos = Vec3(x=7.5, z=40.0);
    blend = TickBlend(tick=12, alpha=0.5);
    assert blend.place(body.tick_pose, body.pos).x == 6.0;
    assert blend.place(rocket.tick_pose, rocket.pos).x == 3.75;
    # Only occupied areas are walked: an empty one is not indexed.
    assert len([world->:Occupied:->]) == 1;
    move_to_area(body, empty);
    assert [world->:Occupied:->] == [empty];
    world spawn CaptureMotion(tick=13);
    assert body.tick_pose.tick == 13 and rocket.tick_pose.tick == 13;
}

test "models are gathered where their bodies are between ticks" {
    world = World();
    area = Area(
        name="a",
        bounds=AABB(mins=Vec3(x=-500.0, y=-500.0, z=-500.0), maxs=Vec3(x=500.0, y=500.0, z=500.0))
    );
    world ++> area;
    grunt = Entity(pos=Vec3(x=0.0), yaw=0.0);
    move_to_area(grunt, area);
    visual = Visual();
    grunt +>:HasVisual:+> visual;
    visual +>:UsesModel:+> ModelResource(name="m", model=AnimatedModel(), skins=[]);
    world spawn CaptureMotion(tick=1);
    grunt.pos = Vec3(x=4.0);
    grunt.yaw = 0.4;
    scene = world spawn GatherModels(blend=TickBlend(tick=1, alpha=0.75));
    assert len(scene.draws) == 1;
    assert abs(scene.draws[0].origin.x - 3.0) < 0.00001;
    assert abs(scene.draws[0].yaw - 0.3) < 0.00001;
}

test "a mover's brushes are drawn between their tick placements" {
    lead = Face(motion=Vec3(z=10.0));
    group = BrushGroup(lead=0, faces=[0]);
    group.hold(lead, 4);
    lead.motion = Vec3(z=14.0);
    lead.turn = model_basis(math.radians(20.0), 0.0);
    placed = group.placed(lead, TickBlend(tick=4, alpha=0.5));
    assert abs(placed.motion.z - 12.0) < 0.00001;
    turn = placed.turn;
    assert turn is not None;
    # Half of the 20 degree turn, still orthonormal.
    assert abs(math.degrees(math.atan2(turn.forward.y, turn.forward.x)) - 10.0) < 0.01;
    assert abs(turn.forward.length() - 1.0) < 0.00001;
    assert abs(turn.left.length() - 1.0) < 0.00001;
    assert abs(turn.forward.dot(turn.left)) < 0.00001 and abs(turn.up.z - 1.0) < 0.00001;
    # Before the group's first hold (it was just regrouped) it is where it is.
    fresh = BrushGroup(lead=0, faces=[0]);
    assert fresh.placed(lead, TickBlend(tick=4, alpha=0.5)).motion.z == 14.0;
    assert blend_basis(None, None, 0.5) is None;
}

test "the physics clock's alpha is how far the frame is into the next tick" {
    clock = Clock(tick_rate=0.01, max_ticks_per_frame=30);
    assert clock.advance(0.025) == 2;
    assert abs(clock.alpha() - 0.5) < 0.00001;
    assert clock.advance(0.004) == 0;
    assert abs(clock.alpha() - 0.9) < 0.00001;
}
