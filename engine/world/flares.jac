"""Q3 light flares (tr_flares.c): the glare a bright light leaves in the eye.

A map's flare surfaces (MST_FLARE) hold no geometry, only a point on a light,
its colour and the way it faces. Each is a `LightFlare` on the world; once a
view `WatchFlares` walks them as RB_AddFlare, RB_TestFlare and
RB_RenderFlares do: a flare among the view's visible surfaces and on screen
is added, tested against the depth of what was drawn at its pixel, and faded
up or down over a moment so it never pops.

The walk asks the view two things through a `FlareLens`: where a point falls
on screen (RB_AddFlare's transform and clip test) and how deep the scene
drawn there is (RB_TestFlare's qglReadPixels of the depth buffer). The
renderer's lens answers from the frame's matrices and depth buffer
(engine/render/flares.jac), so a wall, a door or a model in front of a light
hides its flare.

A flare is kept apart for the main view and for the view through a portal
or mirror (flare_t inPortal): each has its own `FlareSight`."""
import from .world { World }
import from ..math.vec3 { Vec3 }
import from ..formats.bsp { FlareSurface }

edge HasFlare: World --> LightFlare {}

# RB_TestFlare: how much nearer than the flare the scene may be before it
# hides it.
glob FLARE_DEPTH_SLACK: float = 24.0;

"""Where a flare's point falls in a view (RB_AddFlare's windowX, windowY and
eyeZ): across and up the view from -1 to 1, and how deep along it."""
obj FlarePlace {
    has on_screen: bool = False,
        x: float = 0.0,
        y: float = 0.0,
        depth: float = 0.0;
}

"""The view a frame's flares are seen through. `place` is where a world point
falls in it, off screen when it is outside the view's clip volume
(R_TransformModelToClip and RB_AddFlare's clip test); `scene_depth` is how
deep along the view the scene drawn at that place is (RB_TestFlare)."""
obj FlareLens {
    def place(point: Vec3) -> FlarePlace abst;
    def scene_depth(spot: FlarePlace) -> float abst;
}

"""What flare_t keeps for a flare in one view from frame to frame: the frame
it was last added in, whether its last test saw it, when that changed, how
bright it draws, and its last colour (dimmed as the light turns away) and
place."""
obj FlareSight {
    has added: int = -2,
        visible: bool = False,
        fade_time: float = 0.0,
        intensity: float = 0.0,
        shade: Vec3 = Vec3(),
        spot: FlarePlace = FlarePlace();

    """RB_AddFlare: the flare is in view this `frame` at `spot`, coloured
    `shade`. One that was not added last frame starts hidden and long faded,
    so it fades in from nothing."""
    def add(frame: int, now: float, shade: Vec3, spot: FlarePlace) {
        if self.added != frame - 1 {
            self.visible = False;
            self.fade_time = now - 2.0;
        }
        self.added = frame;
        self.shade = shade;
        self.spot = spot;
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

"""One flare surface (tr_bsp.c ParseFlare): the point on the light, its
colour, the way it faces and the fog volume it lies in, and how the main
view and the view through a portal last saw it."""
node LightFlare {
    has face: int,
        origin: Vec3,
        color: Vec3,
        normal: Vec3,
        fog: int = -1,
        main: FlareSight = FlareSight(),
        portal: FlareSight = FlareSight();

    def sight(portal: bool) -> FlareSight {
        return self.portal if portal else self.main;
    }

    """RB_AddFlare's colour from `eye`: the light's, faded down as its
    surface turns away from the viewer."""
    def shade_from(eye: Vec3) -> Vec3 {
        facing = eye.sub(self.origin).normalized().dot(self.normal);
        return self.color.scale(max(0.0, facing));
    }
}

"""Give the world a LightFlare for each of a map's flare surfaces."""
def seed_flares(world: World, surfaces: list[FlareSurface]) {
    for surface in surfaces {
        world +>:HasFlare:+> LightFlare(
            face=surface.face, origin=surface.origin, color=surface.color, normal=surface.normal, fog=surface.fog,
            main=FlareSight(), portal=FlareSight()
        );
    }
}

"""One view's pass over the world's flares. `shown` holds the flare faces
among the view's visible surfaces and `portal` says the view is the one
through a portal or mirror; `lit` collects the flares to draw, each with its
sight's `intensity`, `shade` and `spot` set. `adds` and `tests` count as the
original's c_flareAdds and c_flareTests do."""
walker WatchFlares {
    has lens: FlareLens,
        eye: Vec3 = Vec3(),
        shown: dict[int, bool] = {},
        frame: int = 0,
        now: float = 0.0,
        fade_rate: float = 7.0,
        portal: bool = False,
        lit: list[LightFlare] = [],
        adds: int = 0,
        tests: int = 0;

    can begin with World entry {
        visit [here->:HasFlare:->];
    }

    can watch with LightFlare entry {
        sight = here.sight(self.portal);
        if here.face in self.shown {
            spot = self.lens.place(here.origin);
            if spot.on_screen {
                sight.add(self.frame, self.now, here.shade_from(self.eye), spot);
                self.adds += 1;
            }
        }
        # RB_RenderFlares throws out a flare that was added neither this
        # frame nor the last; one added last frame is still tested where it
        # was, and so fades rather than vanishing as it leaves the view.
        if sight.added < self.frame - 1 {
            sight.intensity = 0.0;
            return;
        }
        self.tests += 1;
        seen = sight.spot.depth - self.lens.scene_depth(sight.spot) < FLARE_DEPTH_SLACK;
        sight.settle(seen, self.now, self.fade_rate);
        if sight.intensity > 0.0 {
            self.lit.append(here);
        }
    }
}
