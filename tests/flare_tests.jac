"""Q3 light flares: the world's flare nodes and the frame's walk over them."""
import from engine.world.world { World }
import from engine.world.flares { LightFlare, HasFlare, FlareView, WatchFlares, seed_flares, FLARE_DEPTH_SLACK }
import from engine.formats.bsp { FlareSurface }
import from engine.render.flares { FlareCvars, flare_reach }
import from engine.math.vec3 { Vec3 }

"""A world with one flare 200 units ahead of the origin, facing back at it."""
def lamp_world() -> World {
    world = World();
    seed_flares(
        world,
        [FlareSurface(face=7, origin=Vec3(x=200.0), color=Vec3(x=1.0, y=0.5, z=0.25), normal=Vec3(x=-1.0))]
    );
    return world;
}

"""Walk `world`'s flares for frame `frame` at `now` from `eye` looking along +x."""
def watch(world: World, frame: int, now: float, shown: dict[int, bool], eye: Vec3 = Vec3()) -> WatchFlares {
    return world spawn WatchFlares(
        view=FlareView(eye=eye, forward=Vec3(x=1.0), right=Vec3(y=-1.0), up=Vec3(z=1.0), tan_x=1.0, tan_y=0.5625),
        shown=shown, frame=frame, now=now, fade_rate=7.0
    );
}

test "flares are off by default and sized as the original sizes them" {
    cvars = FlareCvars();
    assert not cvars.flares.on() and cvars.size.number == 40.0 and cvars.fade.number == 7.0;
    # RB_RenderFlare: width * (r_flareSize / 640 + 8 / depth) pixels each way.
    # In a view one unit wide each way at unit depth, a pixel at depth d is
    # 2 d / width units.
    assert abs(flare_reach(200.0, 40.0, 1.0) - (40.0 / 640.0 + 8.0 / 200.0) * 400.0) < 0.0001;
    # The fixed part keeps its size on screen; the rest shrinks with distance.
    near = flare_reach(100.0, 40.0, 1.0) / 100.0;
    far = flare_reach(1000.0, 40.0, 1.0) / 1000.0;
    assert near > far and abs(far - 2.0 * (40.0 / 640.0 + 8.0 / 1000.0)) < 0.0001;
}

test "a flare in view fades in over a seventh of a second and is dimmed as it turns away" {
    world = lamp_world();
    flares = [world->:HasFlare:->][?:LightFlare];
    assert len(flares) == 1 and flares[0].face == 7;
    first = watch(world, 1, 10.0, {7: True});
    # RB_TestFlare: just seen, it starts a millisecond into its fade.
    assert len(first.lit) == 1 and abs(first.lit[0].intensity - 0.007) < 0.0001;
    assert first.lit[0].depth == 200.0 and first.lit[0].visible;
    half = watch(world, 2, 10.0 + 1.0 / 14.0, {7: True});
    assert abs(half.lit[0].intensity - (0.5 + 0.007)) < 0.0001;
    full = watch(world, 3, 10.5, {7: True});
    assert full.lit[0].intensity == 1.0;
    # Seen square on, the flare keeps its colour.
    assert full.lit[0].shade.sub(Vec3(x=1.0, y=0.5, z=0.25)).length() < 0.0001;
    # Off its normal it has the cosine of the angle left (a 3-4-5 triangle).
    side = watch(world, 4, 10.6, {7: True}, Vec3(x=120.0, y=-60.0));
    assert abs(side.lit[0].shade.x - 0.8) < 0.0001 and abs(side.lit[0].depth - 80.0) < 0.0001;
}

test "a flare off screen, behind its surface or out of the visible set is dropped at once" {
    world = lamp_world();
    watch(world, 1, 1.0, {7: True});
    assert watch(world, 2, 2.0, {7: True}).lit[0].intensity == 1.0;
    # Not among the visible faces: RB_RenderFlares throws it out.
    assert not watch(world, 3, 2.1, {}).lit;
    flare = [world->:HasFlare:->][?:LightFlare][0];
    assert flare.intensity == 0.0;
    # Back in view it fades in again from nothing.
    again = watch(world, 4, 2.2, {7: True});
    assert abs(again.lit[0].intensity - 0.007) < 0.0001;
    # Off to the side of the view (RB_AddFlare's clip test) and behind the eye.
    assert not watch(world, 5, 2.3, {7: True}, Vec3(y=300.0)).lit;
    assert not watch(world, 6, 2.4, {7: True}, Vec3(x=400.0)).lit;
    # Seen from behind the light surface it has no colour left.
    view = FlareView(eye=Vec3(x=400.0), forward=Vec3(x=-1.0), right=Vec3(y=1.0), up=Vec3(z=1.0));
    behind = world spawn WatchFlares(view=view, shown={7: True}, frame=7, now=2.5);
    assert len(behind.lit) == 1 and behind.lit[0].shade.length() == 0.0;
}

test "a hidden flare fades out and comes back when it is seen again" {
    flare = LightFlare(face=1, origin=Vec3(), color=Vec3(x=1.0), normal=Vec3(z=1.0));
    flare.add(1, 5.0, Vec3(z=100.0), 100.0);
    flare.settle(True, 5.0, 7.0);
    flare.add(2, 6.0, Vec3(z=100.0), 100.0);
    flare.settle(True, 6.0, 7.0);
    assert flare.intensity == 1.0 and flare.visible;
    # Something moves in front: it fades from the moment it was hidden.
    flare.add(3, 6.1, Vec3(z=100.0), 100.0);
    flare.settle(False, 6.1, 7.0);
    assert not flare.visible and abs(flare.intensity - (1.0 - 0.007)) < 0.0001;
    flare.add(4, 6.1 + 1.0 / 14.0, Vec3(z=100.0), 100.0);
    flare.settle(False, 6.1 + 1.0 / 14.0, 7.0);
    assert abs(flare.intensity - (0.5 - 0.007)) < 0.0001;
    flare.add(5, 7.0, Vec3(z=100.0), 100.0);
    flare.settle(False, 7.0, 7.0);
    assert flare.intensity == 0.0;
    flare.add(6, 7.1, Vec3(z=100.0), 100.0);
    flare.settle(True, 7.1, 7.0);
    assert flare.visible and abs(flare.intensity - 0.007) < 0.0001;
    assert FLARE_DEPTH_SLACK == 24.0;
}
