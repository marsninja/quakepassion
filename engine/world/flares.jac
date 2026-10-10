"""Q3 light flares (tr_flares.c): the glare a bright light leaves in the eye.

A map's flare surfaces (MST_FLARE) hold no geometry, only a point on a light,
its colour and the way it faces. Each is a `LightFlare` on the world; once a
frame `WatchFlares` walks them as RB_AddFlare, RB_TestFlare and
RB_RenderFlares do: a flare among the view's visible surfaces and on screen
is added, tested against what stands between it and the eye, and faded up or
down over a moment so it never pops.

The original reads the depth buffer back at the flare's pixel
(qglReadPixels). Here a trace through the world from the eye stands in for
it, so a wall or a door hides a flare and a model in front of it does not."""
import from .world { World }
import from ..math.vec3 { Vec3 }
import from ..formats.bsp { FlareSurface }
import from ..physics.collision { CollisionMap }

edge HasFlare: World --> LightFlare {}

# RB_TestFlare: how much nearer than the flare the scene may be before it
# hides it.
glob FLARE_DEPTH_SLACK: float = 24.0;

"""One flare surface (tr_bsp.c ParseFlare) and what flare_t keeps for it from
frame to frame: the frame it was last added in, whether its last test saw it,
when that changed, how bright it draws, and this frame's colour (dimmed as
the light turns away) and depth along the view."""
node LightFlare {
    has face: int,
        origin: Vec3,
        color: Vec3,
        normal: Vec3,
        added: int = -2,
        visible: bool = False,
        fade_time: float = 0.0,
        intensity: float = 0.0,
        shade: Vec3 = Vec3(),
        depth: float = 0.0;

    """RB_AddFlare: the flare is in view this `frame`. One that was not added
    last frame starts hidden and long faded, so it fades in from nothing."""
    def add(frame: int, now: float, eye: Vec3, depth: float) {
        if self.added != frame - 1 {
            self.visible = False;
            self.fade_time = now - 2.0;
        }
        self.added = frame;
        # Fade the flare down as the light surface turns away from the viewer.
        facing = eye.sub(self.origin).normalized().dot(self.normal);
        self.shade = self.color.scale(max(0.0, facing));
        self.depth = depth;
    }

    """RB_TestFlare: `seen` is this frame's depth test. The intensity climbs
    from the moment the flare came into sight and falls from the moment it
    was hidden, at `rate` (r_flareFade) a second."""
    def settle(seen: bool, now: float, rate: float) {
        fade = 0.0;
        if seen {
            if not self.visible {
                self.visible = True;
                self.fade_time = now - 0.001;
            }
            fade = (now - self.fade_time) * rate;
        } else {
            if self.visible {
                self.visible = False;
                self.fade_time = now - 0.001;
            }
            fade = 1.0 - (now - self.fade_time) * rate;
        }
        self.intensity = max(0.0, min(1.0, fade));
    }
}

"""The view a frame's flares are tested from: the eye, its axes, and the
tangents of half its horizontal and vertical angles."""
obj FlareView {
    has eye: Vec3 = Vec3(),
        forward: Vec3 = Vec3(x=1.0),
        right: Vec3 = Vec3(y=-1.0),
        up: Vec3 = Vec3(z=1.0),
        tan_x: float = 1.0,
        tan_y: float = 1.0,
        near: float = 1.0;

    """A point's depth along the view, or 0 when it is off screen
    (RB_AddFlare's clip test)."""
    def depth_of(point: Vec3) -> float {
        delta = point.sub(self.eye);
        depth = delta.dot(self.forward);
        if depth <= self.near {
            return 0.0;
        }
        if abs(delta.dot(self.right)) >= depth * self.tan_x or abs(delta.dot(self.up)) >= depth * self.tan_y {
            return 0.0;
        }
        return depth;
    }
}

"""Give the world a LightFlare for each of a map's flare surfaces."""
def seed_flares(world: World, surfaces: list[FlareSurface]) {
    for surface in surfaces {
        world +>:HasFlare:+> LightFlare(
            face=surface.face, origin=surface.origin, color=surface.color, normal=surface.normal
        );
    }
}

"""One frame's pass over the world's flares. `shown` holds the flare faces
among the view's visible surfaces; `lit` collects the flares to draw, each
with its `intensity`, `shade` and `depth` set."""
walker WatchFlares {
    has view: FlareView = FlareView(),
        shown: dict[int, bool] = {},
        frame: int = 0,
        now: float = 0.0,
        fade_rate: float = 7.0,
        collision: CollisionMap | None = None,
        lit: list[LightFlare] = [];

    can begin with World entry {
        visit [here->:HasFlare:->];
    }

    can watch with LightFlare entry {
        if here.face in self.shown {
            depth = self.view.depth_of(here.origin);
            if depth > 0.0 {
                here.add(self.frame, self.now, self.view.eye, depth);
            }
        }
        # RB_RenderFlares throws out a flare that was not added this frame.
        if here.added != self.frame {
            here.intensity = 0.0;
        } else {
            here.settle(self.sees(here), self.now, self.fade_rate);
            if here.intensity > 0.0 {
                self.lit.append(here);
            }
        }
    }

    """Whether nothing in the world stands more than FLARE_DEPTH_SLACK nearer
    than the flare along its line of sight."""
    def sees(flare: LightFlare) -> bool {
        if self.collision is None {
            return True;
        }
        reached = self.collision.trace_point(self.view.eye, flare.origin).fraction;
        return flare.depth * (1.0 - reached) < FLARE_DEPTH_SLACK;
    }
}
