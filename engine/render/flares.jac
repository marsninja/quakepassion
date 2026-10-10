"""Drawing Q3 light flares (tr_flares.c RB_RenderFlares): each flare a view's
WatchFlares walk left lit is one additive quad of the flareShader's image,
facing the camera, nearly the same size on screen at any distance, over
everything in the view (the original draws them in screen space once the
view is done). The view weapon, drawn afterwards, covers them.

`ViewLens` is the walk's lens on a view being drawn: a point's place comes
from rlgl's matrices, as R_TransformModelToClip has it, and the scene's
depth there from the depth buffer, read back a pixel a flare as
RB_TestFlare does. The view through a portal or mirror draws its own
flares into its own image, with its own lens."""
import math;
import from .effects { EffectQuads, EFFECT_BLEND_ADD, effect_byte }
import from .models { upload_skin }
import from .quake { rlUnloadTexture, rlTextureParameters, fog_coords, fog_density }
import from .gpu { Matrix, view_projection, view_matrix, projection_matrix, read_depth }
import from ..console.cvar { Cvar, CVAR_ARCHIVE }
import from ..console.shell { Shell }
import from ..world.world { World }
import from ..world.level { Level }
import from ..world.flares { WatchFlares, FlareLens, FlarePlace }
import from ..math.vec3 { Vec3 }

"""tr_init.c: flares are off unless r_flares is set; r_flareSize is the part
of a flare's size that does not shrink with distance (in 640ths of the
view's width) and r_flareFade how fast one fades in and out, per second."""
obj FlareCvars {
    has flares: Cvar = Cvar(
            name="r_flares",
            reset_text="0",
            kind="bool",
            flags=CVAR_ARCHIVE,
            description="draw light flares"
        ),
        size: Cvar = Cvar(
            name="r_flareSize",
            reset_text="40",
            kind="float",
            low=0.0,
            high=640.0,
            description="a flare's size on screen, in 640ths of the view's width"
        ),
        fade: Cvar = Cvar(
            name="r_flareFade",
            reset_text="7",
            kind="float",
            low=0.1,
            high=1000.0,
            description="how fast a flare fades in and out, per second"
        );
}

"""How much of a flare's colour the fog volume it lies in lets through
(tr_shader.c: an additive shader's colours are modulated by fog, as
RB_CalcModulateColorsByFog does), 1 outside fog. The original takes the fog
at the corners of the flare's quad, which RB_RenderFlare gives in window
coordinates but RB_CalcFogTexCoords reads as world ones; here it is the fog
at the light itself, seen from `eye` along `forward`."""
def flare_fog(level: Level, fog: int, origin: Vec3, eye: Vec3, forward: Vec3) -> float {
    if fog < 0 or fog >= len(level.bsp.fogs) {
        return 1.0;
    }
    coords = fog_coords(level.bsp.fogs[fog], origin, eye, forward);
    return 1.0 - fog_density(coords[0], coords[1]);
}

"""How far a flare's quad reaches from its centre, in world units at its
`depth`, to cover what RB_RenderFlare draws: viewportWidth * (r_flareSize /
640 + 8 / depth) pixels each way, a view `tan_x` wide at unit depth."""
def flare_reach(depth: float, size: float, tan_x: float) -> float {
    return (size / 640.0 + 8.0 / depth) * 2.0 * depth * tan_x;
}

"""A view's lens from its matrices: `combined` is the view-projection
matrix, `modelview` and `projection` its two halves."""
obj ViewLens(FlareLens) {
    has combined: Matrix,
        modelview: Matrix,
        projection: Matrix;

    """R_TransformModelToClip and RB_AddFlare's clip test: off screen unless
    the point's clip coordinates lie inside the view's volume on all three
    axes."""
    def place(point: Vec3) -> FlarePlace {
        c = self.combined;
        m = self.modelview;
        w = float(c.m3) * point.x + float(c.m7) * point.y + float(c.m11) * point.z + float(c.m15);
        x = float(c.m0) * point.x + float(c.m4) * point.y + float(c.m8) * point.z + float(c.m12);
        y = float(c.m1) * point.x + float(c.m5) * point.y + float(c.m9) * point.z + float(c.m13);
        z = float(c.m2) * point.x + float(c.m6) * point.y + float(c.m10) * point.z + float(c.m14);
        if x >= w or x <= -w or y >= w or y <= -w or z >= w or z <= -w {
            return FlarePlace();
        }
        eye_z = float(m.m2) * point.x + float(m.m6) * point.y + float(m.m10) * point.z + float(m.m14);
        return FlarePlace(on_screen=True, x=x / w, y=y / w, depth=-eye_z);
    }

    """RB_TestFlare's screenZ: how deep along the view the surface is whose
    depth buffer value at `spot` is `value` (0 near, 1 far). The original's
    form holds for a plain perspective projection; this one also takes the
    slanted near plane a portal view is clipped with."""
    def depth_from(spot: FlarePlace, value: float) -> float {
        p = self.projection;
        slant = float(p.m2) * spot.x / float(p.m0) + float(p.m6) * spot.y / float(p.m5);
        divisor = slant - float(p.m10) - (2.0 * value - 1.0);
        if divisor == 0.0 {
            return 1000000.0;
        }
        return -float(p.m14) / divisor;
    }

    def scene_depth(spot: FlarePlace) -> float {
        return self.depth_from(spot, read_depth(spot.x, spot.y));
    }
}

"""`adds`, `tests` and `renders` count the last view's flares as the
original's c_flareAdds, c_flareTests and c_flareRenders do."""
obj FlareRenderer {
    has cvars: FlareCvars = FlareCvars(),
        texture: int = 0,
        frame: int = 0,
        portal_frame: int = 0,
        adds: int = 0,
        tests: int = 0,
        renders: int = 0;

    """Register the flares' cvars."""
    def declare(shell: Shell) {
        self.cvars.flares = shell.register(self.cvars.flares);
        self.cvars.size = shell.register(self.cvars.size);
        self.cvars.fade = shell.register(self.cvars.fade);
    }

    """Take the level's flare image (the flareShader's map), if it has flares."""
    def upload(level: Level) {
        self.close();
        if level.flare_image is None {
            return;
        }
        self.texture = upload_skin(level.flare_image);
        rlTextureParameters(u32(self.texture), i32(10242), i32(33071));
        rlTextureParameters(u32(self.texture), i32(10243), i32(33071));
    }

    """Walk the world's flares for the view being drawn (its matrices are
    rlgl's current ones and its scene is in the depth buffer) and draw the
    lit ones through `quads`. `shown` holds the flare faces among the view's
    visible surfaces, `eye` and `forward` are the view's, `now` the time in
    seconds and `portal` says it is the view through a portal or mirror."""
    def draw(
        world: World,
        level: Level,
        shown: dict[int, bool],
        quads: EffectQuads,
        eye: Vec3,
        forward: Vec3,
        now: float,
        portal: bool = False
    ) {
        self.adds = 0;
        self.tests = 0;
        self.renders = 0;
        if self.texture == 0 or not self.cvars.flares.on() {
            return;
        }
        lens = ViewLens(combined=view_projection(), modelview=view_matrix(), projection=projection_matrix());
        frame = 0;
        if portal {
            self.portal_frame += 1;
            frame = self.portal_frame;
        } else {
            self.frame += 1;
            frame = self.frame;
        }
        watch = world spawn WatchFlares(
            lens=lens, eye=eye, shown=shown, frame=frame, now=now, fade_rate=self.cvars.fade.number, portal=portal
        );
        self.adds = watch.adds;
        self.tests = watch.tests;
        self.renders = len(watch.lit);
        if not watch.lit {
            return;
        }
        # The quads face the view; a mirror's flipped projection flips them
        # with everything else.
        side = forward.cross(Vec3(z=1.0));
        if side.length() < 0.001 {
            side = Vec3(y=-1.0);
        }
        side = side.normalized();
        tan_x = 1.0 / max(0.0001, abs(float(lens.projection.m0)));
        quads.open();
        quads.side = side;
        quads.up = side.cross(forward).normalized();
        for flare in watch.lit {
            sight = flare.sight(portal);
            reach = flare_reach(sight.spot.depth, self.cvars.size.number, tan_x);
            color = sight.shade.scale(sight.intensity * flare_fog(level, flare.fog, flare.origin, eye, forward));
            quads.add(
                self.texture, EFFECT_BLEND_ADD, flare.origin, Vec3(), Vec3(),
                -reach, -reach, reach, reach, 0.0, 1.0, 1.0, 0.0,
                effect_byte(color.x), effect_byte(color.y), effect_byte(color.z), 255
            );
        }
        quads.flush(depth_test=False);
    }

    def close() {
        if self.texture != 0 {
            rlUnloadTexture(u32(self.texture));
            self.texture = 0;
        }
    }
}
