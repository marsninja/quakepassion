"""Q3 light flares: the world's flare nodes, the view's walk over them and
the lens the walk sees them through."""
import from engine.world.world { World }
import from engine.world.flares {
    LightFlare,
    HasFlare,
    FlareSight,
    FlarePlace,
    FlareLens,
    WatchFlares,
    seed_flares,
    FLARE_DEPTH_SLACK
}
import from engine.formats.bsp { FlareSurface, FogVolume, Bsp }
import from engine.render.flares { FlareCvars, ViewLens, flare_reach, flare_fog }
import from engine.render.gpu { Matrix }
import from engine.world.level { Level }
import from engine.math.vec3 { Vec3 }

"""A view from `eye` along +x, one unit wide and 0.5625 tall each way at
unit depth, with the scene `scene` deep everywhere."""
obj PlainLens(FlareLens) {
    has eye: Vec3 = Vec3(),
        scene: float = 100000.0;

    def place(point: Vec3) -> FlarePlace {
        delta = point.sub(self.eye);
        if delta.x <= 1.0 or abs(delta.y) >= delta.x or abs(delta.z) >= delta.x * 0.5625 {
            return FlarePlace();
        }
        return FlarePlace(on_screen=True, x=-delta.y / delta.x, y=delta.z / (delta.x * 0.5625), depth=delta.x);
    }

    def scene_depth(spot: FlarePlace) -> float {
        return self.scene;
    }
}

"""A world with one flare 200 units ahead of the origin, facing back at it."""
def lamp_world() -> World {
    world = World();
    seed_flares(
        world,
        [FlareSurface(face=7, origin=Vec3(x=200.0), color=Vec3(x=1.0, y=0.5, z=0.25), normal=Vec3(x=-1.0), fog=3)]
    );
    return world;
}

"""Walk `world`'s flares for frame `frame` at `now` from `eye` looking along +x."""
def watch(
    world: World, frame: int, now: float, shown: dict[int, bool], eye: Vec3 = Vec3(), scene: float = 100000.0,
    portal: bool = False
) -> WatchFlares {
    return world spawn WatchFlares(
        lens=PlainLens(eye=eye, scene=scene), eye=eye, shown=shown, frame=frame, now=now, fade_rate=7.0, portal=portal
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
    assert len(flares) == 1 and flares[0].face == 7 and flares[0].fog == 3;
    first = watch(world, 1, 10.0, {7: True});
    # RB_TestFlare: just seen, it starts a millisecond into its fade.
    assert len(first.lit) == 1 and abs(first.lit[0].main.intensity - 0.007) < 0.0001;
    assert first.lit[0].main.spot.depth == 200.0 and first.lit[0].main.visible;
    assert first.adds == 1 and first.tests == 1;
    half = watch(world, 2, 10.0 + 1.0 / 14.0, {7: True});
    assert abs(half.lit[0].main.intensity - (0.5 + 0.007)) < 0.0001;
    full = watch(world, 3, 10.5, {7: True});
    assert full.lit[0].main.intensity == 1.0;
    # Seen square on, the flare keeps its colour.
    assert full.lit[0].main.shade.sub(Vec3(x=1.0, y=0.5, z=0.25)).length() < 0.0001;
    # Off its normal it has the cosine of the angle left (a 3-4-5 triangle).
    side = watch(world, 4, 10.6, {7: True}, Vec3(x=120.0, y=-60.0));
    assert abs(side.lit[0].main.shade.x - 0.8) < 0.0001 and abs(side.lit[0].main.spot.depth - 80.0) < 0.0001;
    # Seen from behind the light surface it has no colour left.
    assert flares[0].shade_from(Vec3(x=400.0)).length() == 0.0;
}

test "the depth buffer hides a flare, whatever stands in front of it" {
    world = lamp_world();
    watch(world, 1, 1.0, {7: True});
    assert watch(world, 2, 2.0, {7: True}).lit[0].main.intensity == 1.0;
    # RB_TestFlare: the scene at its pixel is within 24 units of the flare.
    assert FLARE_DEPTH_SLACK == 24.0;
    grazed = watch(world, 3, 2.1, {7: True}, scene=177.0);
    assert grazed.lit[0].main.visible and grazed.lit[0].main.intensity == 1.0;
    # Something 50 units nearer than the light is drawn over it (a wall, a
    # door or a model: the test only sees depth). It fades from that moment.
    hidden = watch(world, 4, 2.2, {7: True}, scene=150.0);
    flare = hidden.lit[0];
    assert not flare.main.visible and abs(flare.main.intensity - (1.0 - 0.007)) < 0.0001;
    assert abs(watch(world, 5, 2.2 + 1.0 / 14.0, {7: True}, scene=150.0).lit[0].main.intensity - (0.5 - 0.007)) < 0.0001;
    gone = watch(world, 6, 3.0, {7: True}, scene=150.0);
    assert not gone.lit and flare.main.intensity == 0.0 and gone.tests == 1;
    # It moves away: the flare fades in again.
    back = watch(world, 7, 3.1, {7: True});
    assert back.lit[0].main.visible and abs(back.lit[0].main.intensity - 0.007) < 0.0001;
}

test "a flare that leaves the view is tested one frame more, then thrown out" {
    world = lamp_world();
    watch(world, 1, 1.0, {7: True});
    assert watch(world, 2, 2.0, {7: True}).lit[0].main.intensity == 1.0;
    flare = [world->:HasFlare:->][?:LightFlare][0];
    # Not among the visible faces: added last frame, it is still tested where
    # it was (RB_RenderFlares keeps addedFrame >= frameCount - 1).
    kept = watch(world, 3, 2.1, {});
    assert kept.adds == 0 and kept.tests == 1 and len(kept.lit) == 1 and flare.main.added == 2;
    # The frame after, it is gone.
    dropped = watch(world, 4, 2.2, {});
    assert not dropped.lit and dropped.tests == 0 and flare.main.intensity == 0.0;
    # Back in view it fades in again from nothing.
    again = watch(world, 5, 2.3, {7: True});
    assert abs(again.lit[0].main.intensity - 0.007) < 0.0001;
    # Off to the side of the view (RB_AddFlare's clip test) and behind the eye
    # it is not added.
    assert watch(world, 6, 2.4, {7: True}, Vec3(y=300.0)).adds == 0;
    assert watch(world, 7, 2.5, {7: True}, Vec3(x=400.0)).adds == 0;
    assert not watch(world, 8, 2.6, {7: True}, Vec3(x=400.0)).lit;
}

test "the view through a portal keeps its own sight of a flare" {
    world = lamp_world();
    flare = [world->:HasFlare:->][?:LightFlare][0];
    watch(world, 1, 1.0, {7: True});
    watch(world, 2, 2.0, {7: True});
    assert flare.main.intensity == 1.0 and flare.portal.intensity == 0.0;
    # flare_t inPortal: the mirror's view of the same surface starts its own fade.
    mirrored = watch(world, 1, 2.0, {7: True}, Vec3(x=100.0), portal=True);
    assert mirrored.lit[0] is flare and abs(flare.portal.intensity - 0.007) < 0.0001;
    assert flare.portal.spot.depth == 100.0 and flare.main.spot.depth == 200.0 and flare.main.intensity == 1.0;
    # Hidden in the main view, it stays lit in the mirror.
    watch(world, 3, 3.0, {7: True}, scene=10.0);
    watch(world, 2, 3.0, {7: True}, Vec3(x=100.0), portal=True);
    assert not flare.main.visible and flare.portal.visible and flare.portal.intensity == 1.0;
}

test "a sight fades out when hidden and comes back when it is seen again" {
    sight = FlareSight();
    spot = FlarePlace(on_screen=True, depth=100.0);
    sight.add(1, 5.0, Vec3(x=1.0), spot);
    sight.settle(True, 5.0, 7.0);
    sight.add(2, 6.0, Vec3(x=1.0), spot);
    sight.settle(True, 6.0, 7.0);
    assert sight.intensity == 1.0 and sight.visible;
    sight.add(3, 6.1, Vec3(x=1.0), spot);
    sight.settle(False, 6.1, 7.0);
    assert not sight.visible and abs(sight.intensity - (1.0 - 0.007)) < 0.0001;
    sight.add(4, 7.0, Vec3(x=1.0), spot);
    sight.settle(False, 7.0, 7.0);
    assert sight.intensity == 0.0;
    sight.add(5, 7.1, Vec3(x=1.0), spot);
    sight.settle(True, 7.1, 7.0);
    assert sight.visible and abs(sight.intensity - 0.007) < 0.0001;
    # A frame missed: added again, it starts hidden and long faded.
    sight.add(9, 9.0, Vec3(x=1.0), spot);
    assert not sight.visible and sight.fade_time == 7.0;
}

"""A view down -z (rlgl's eye space) with a 90 degree field of view, near
plane 4 and far plane 4096, as raylib's perspective matrix has it, and its
eye `back` units up +z from the origin."""
def perspective_lens(back: float) -> ViewLens {
    near = 4.0;
    far = 4096.0;
    projection = Matrix(
        m0=f32(1.0), m4=f32(0.0), m8=f32(0.0), m12=f32(0.0),
        m1=f32(0.0), m5=f32(1.0), m9=f32(0.0), m13=f32(0.0),
        m2=f32(0.0), m6=f32(0.0), m10=f32(-(far + near) / (far - near)), m14=f32(-2.0 * far * near / (far - near)),
        m3=f32(0.0), m7=f32(0.0), m11=f32(-1.0), m15=f32(0.0)
    );
    modelview = Matrix(
        m0=f32(1.0), m4=f32(0.0), m8=f32(0.0), m12=f32(0.0),
        m1=f32(0.0), m5=f32(1.0), m9=f32(0.0), m13=f32(0.0),
        m2=f32(0.0), m6=f32(0.0), m10=f32(1.0), m14=f32(-back),
        m3=f32(0.0), m7=f32(0.0), m11=f32(0.0), m15=f32(1.0)
    );
    # The two multiplied: the translation only reaches the third and fourth rows.
    combined = Matrix(
        m0=f32(1.0), m4=f32(0.0), m8=f32(0.0), m12=f32(0.0),
        m1=f32(0.0), m5=f32(1.0), m9=f32(0.0), m13=f32(0.0),
        m2=f32(0.0), m6=f32(0.0), m10=projection.m10, m14=f32(float(projection.m14) - back * float(projection.m10)),
        m3=f32(0.0), m7=f32(0.0), m11=f32(-1.0), m15=f32(back)
    );
    return ViewLens(combined=combined, modelview=modelview, projection=projection);
}

test "the view's lens places a point as the clip transform does and reads depth back to distance" {
    lens = perspective_lens(100.0);
    # 300 units ahead of the eye, 150 to the right and 75 up: half way and a
    # quarter of the way across a view as wide as it is deep.
    spot = lens.place(Vec3(x=150.0, y=75.0, z=-200.0));
    assert spot.on_screen and abs(spot.depth - 300.0) < 0.001;
    assert abs(spot.x - 0.5) < 0.0001 and abs(spot.y - 0.25) < 0.0001;
    # RB_AddFlare's clip test: outside the view on any axis, or behind the eye.
    assert not lens.place(Vec3(x=301.0, z=-200.0)).on_screen;
    assert not lens.place(Vec3(y=-301.0, z=-200.0)).on_screen;
    assert not lens.place(Vec3(z=200.0)).on_screen;
    assert not lens.place(Vec3(z=97.0)).on_screen;
    # RB_TestFlare's screenZ: the depth buffer's value for a surface 300
    # units deep reads back as 300.
    p = lens.projection;
    ndc = (float(p.m10) * -300.0 + float(p.m14)) / 300.0;
    assert abs(lens.depth_from(spot, ndc * 0.5 + 0.5) - 300.0) < 0.01;
    # Nothing drawn (the far plane) is far behind any flare.
    assert lens.depth_from(spot, 1.0) > 4000.0;
    # A portal view's slanted near plane changes the third row; a surface 300
    # deep at this place still reads back as 300.
    slanted = perspective_lens(100.0);
    slanted.projection.m2 = f32(0.2);
    slanted.projection.m6 = f32(-0.1);
    q = slanted.projection;
    eye_x = spot.x * 300.0;
    eye_y = spot.y * 300.0;
    clip_z = float(q.m2) * eye_x + float(q.m6) * eye_y + float(q.m10) * -300.0 + float(q.m14);
    assert abs(slanted.depth_from(spot, clip_z / 300.0 * 0.5 + 0.5) - 300.0) < 0.01;
}

test "a flare in a fog volume is dimmed by the fog between it and the eye" {
    level = Level();
    level.bsp = Bsp(game="q3");
    # A fog 256 units to opaque, with no surface of its own.
    level.bsp.fogs = [FogVolume(depth=256.0)];
    eye = Vec3();
    ahead = Vec3(x=1.0);
    assert flare_fog(level, -1, Vec3(x=128.0), eye, ahead) == 1.0;
    assert flare_fog(level, 5, Vec3(x=128.0), eye, ahead) == 1.0;
    near = flare_fog(level, 0, Vec3(x=32.0), eye, ahead);
    middle = flare_fog(level, 0, Vec3(x=128.0), eye, ahead);
    assert 0.0 < middle and middle < near and near < 1.0;
    # Past the fog's depth nothing of the flare is left.
    assert flare_fog(level, 0, Vec3(x=300.0), eye, ahead) == 0.0;
}
