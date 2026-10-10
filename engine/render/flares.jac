"""Drawing Q3 light flares (tr_flares.c RB_RenderFlares): each flare the frame's
WatchFlares walk left lit is one additive quad of the flareShader's image,
facing the camera, nearly the same size on screen at any distance, over
everything in the view (the original draws them in screen space once the
view is done). The view weapon, drawn afterwards, covers them."""
import math;
import from .effects { EffectQuads, EFFECT_BLEND_ADD, effect_byte }
import from .models { upload_skin }
import from .quake { rlUnloadTexture, rlTextureParameters }
import from ..console.cvar { Cvar, CVAR_ARCHIVE }
import from ..console.shell { Shell }
import from ..world.world { World }
import from ..world.level { Level }
import from ..world.flares { WatchFlares, FlareView }
import from ..math.vec3 { Vec3, forward_from, right_from }

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

"""How far a flare's quad reaches from its centre, in world units at its
`depth`, to cover what RB_RenderFlare draws: viewportWidth * (r_flareSize /
640 + 8 / depth) pixels each way, a view `tan_x` wide at unit depth."""
def flare_reach(depth: float, size: float, tan_x: float) -> float {
    return (size / 640.0 + 8.0 / depth) * 2.0 * depth * tan_x;
}

obj FlareRenderer {
    has cvars: FlareCvars = FlareCvars(),
        texture: int = 0,
        frame: int = 0;

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

    """Walk the world's flares for this view and draw the lit ones through
    `quads`. `shown` holds the flare faces among the visible surfaces, `fov`
    is the view's vertical angle in degrees and `now` the time in seconds."""
    def draw(
        world: World,
        level: Level,
        shown: dict[int, bool],
        quads: EffectQuads,
        eye: Vec3,
        yaw: float,
        pitch: float,
        fov: float,
        aspect: float,
        now: float
    ) {
        if self.texture == 0 or not self.cvars.flares.on() {
            return;
        }
        forward = forward_from(yaw, pitch);
        right = right_from(yaw);
        tan_y = math.tan(fov * math.pi / 360.0);
        view = FlareView(
            eye=eye, forward=forward, right=right, up=right.cross(forward).normalized(),
            tan_x=tan_y * aspect, tan_y=tan_y
        );
        self.frame += 1;
        watch = world spawn WatchFlares(
            view=view, shown=shown, frame=self.frame, now=now,
            fade_rate=self.cvars.fade.number, collision=level.collision
        );
        if not watch.lit {
            return;
        }
        quads.open();
        quads.side = right;
        quads.up = view.up;
        for flare in watch.lit {
            reach = flare_reach(flare.depth, self.cvars.size.number, view.tan_x);
            color = flare.shade.scale(flare.intensity);
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
