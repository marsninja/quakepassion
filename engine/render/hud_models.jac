"""Q3's 3D status bar icons (cg_draw3dIcons 1, the default): the held
weapon's ammo box swinging, the armor spinning and the player's head glancing
about, each drawn by CG_Draw3DModel with a 30 degree view of the model alone.
Each icon renders into a small offscreen target that is then drawn into the
status bar."""
import math;
import from .models { ModelRenderer }
import from .portal { PortalTarget, rlEnableFramebuffer, rlDisableFramebuffer, rlClearColor, rlClearScreenBuffers, rlViewport, GetRenderWidth, GetRenderHeight }
import from .viewweapon { Matrix, rlSetMatrixProjection }
import from .quake { rlDrawRenderBatchActive }
import from .renderer { Camera3D, Vector3, BeginMode3D, EndMode3D }
import from .hud { HudRenderer, HudPic, HudStatus, StatusHead }
import from ..math.vec3 { Vec3 }
import from ..math.orientation { model_basis }

glob ICON_RESOLUTION: int = 256;

"""A symmetric perspective: fov_x = fov_y = 30 degrees, as CG_Draw3DModel sets."""
def icon_projection() -> Matrix {
    f = 1.0 / math.tan(math.radians(15.0));
    near = 1.0;
    far = 2048.0;
    return Matrix(
        m0=f32(f), m4=f32(0.0), m8=f32(0.0), m12=f32(0.0),
        m1=f32(0.0), m5=f32(f), m9=f32(0.0), m13=f32(0.0),
        m2=f32(0.0), m6=f32(0.0), m10=f32(-(far + near) / (far - near)), m14=f32(-2.0 * far * near / (far - near)),
        m3=f32(0.0), m7=f32(0.0), m11=f32(-1.0), m15=f32(0.0)
    );
}

"""CG_DrawHead: centre a head model and back off until it nearly fills the
box, then apply its animation.cfg `headoffset` (per-model tweaking)."""
def head_view(renderer: ModelRenderer, offset: Vec3 = Vec3()) -> Vec3 {
    lo = Vec3(x=100000.0, y=100000.0, z=100000.0);
    hi = Vec3(x=-100000.0, y=-100000.0, z=-100000.0);
    for surface in renderer.model.surfaces {
        if surface.frames {
            for v in surface.frames[0].vertices {
                lo = Vec3(x=min(lo.x, v.x), y=min(lo.y, v.y), z=min(lo.z, v.z));
                hi = Vec3(x=max(hi.x, v.x), y=max(hi.y, v.y), z=max(hi.z, v.z));
            }
        }
    }
    length = 0.7 * (hi.z - lo.z);
    return Vec3(x=length / 0.268, y=0.5 * (lo.y + hi.y), z=-0.5 * (lo.z + hi.z)).add(offset);
}

obj HudModels {
    has ammo: dict[str, ModelRenderer] = {},
        armor: ModelRenderer | None = None,
        head: ModelRenderer | None = None,
        head_origin: Vec3 = Vec3(),
        target: PortalTarget = PortalTarget(),
        status_head: StatusHead = StatusHead();

    def ready() -> bool {
        return self.head is not None;
    }

    """The status bar's head (the player's), placed as CG_DrawHead does."""
    def set_head(renderer: ModelRenderer, offset: Vec3 = Vec3()) {
        self.head = renderer;
        self.head_origin = head_view(renderer, offset);
    }

    """CG_DrawStatusBar's 3D icons over the Q3 status bar laid out by `hud`."""
    def draw(hud: HudRenderer, status: HudStatus, width: int, height: int) {
        if not self.ready() or not self.target.prepare_size(ICON_RESOLUTION, ICON_RESOLUTION) {
            return;
        }
        seconds = status.clock;
        scale = float(height) / 480.0;
        left = (float(width) - 640.0 * scale) * 0.5;
        y = float(height) - 48.0 * scale;
        if status.ammo >= 0 and status.weapon in self.ammo {
            swing = 90.0 + 20.0 * math.sin(seconds);
            self.icon(hud, self.ammo[status.weapon], Vec3(x=70.0), swing, 0.0, left + 100.0 * scale, y, 48.0 * scale, width, height, seconds);
        }
        self.draw_head(hud, status, left + 285.0 * scale, scale, width, height);
        if status.armor > 0 and self.armor is not None {
            spin = float(int(seconds * 1000.0) % 2048) * 360.0 / 2048.0;
            self.icon(hud, self.armor, Vec3(x=90.0, z=-10.0), spin, 0.0, left + 470.0 * scale, y, 48.0 * scale, width, height, seconds);
        }
    }

    def draw_head(hud: HudRenderer, status: HudStatus, x: float, scale: float, width: int, height: int) {
        head = self.head;
        if head is None {
            return;
        }
        pose = self.status_head.pose(status);
        self.icon(hud, head, self.head_origin, pose.yaw, pose.pitch, x - pose.shift * scale, float(height) - pose.size * scale, pose.size * scale, width, height, status.clock);
    }

    """CG_Draw3DModel: render `model` at `origin` turned by (yaw, pitch)
    degrees, seen from the origin along +x, into the box at (x, y) of `size`."""
    def icon(hud: HudRenderer, model: ModelRenderer, origin: Vec3, yaw: float, pitch: float, x: float, y: float, size: float, width: int, height: int, seconds: float = 0.0) {
        rlDrawRenderBatchActive();
        rlEnableFramebuffer(u32(self.target.frame));
        rlViewport(i32(0), i32(0), i32(ICON_RESOLUTION), i32(ICON_RESOLUTION));
        rlClearColor(u8(0), u8(0), u8(0), u8(0));
        rlClearScreenBuffers();
        BeginMode3D(
            Camera3D(
                position=Vector3(x=f32(0.0), y=f32(0.0), z=f32(0.0)),
                target=Vector3(x=f32(1.0), y=f32(0.0), z=f32(0.0)),
                up=Vector3(x=f32(0.0), y=f32(0.0), z=f32(1.0)),
                fovy=f32(30.0),
                projection=i32(0)
            )
        );
        rlSetMatrixProjection(icon_projection());
        model.draw(
            origin,
            math.radians(yaw),
            seconds=seconds,
            basis=model_basis(math.radians(yaw), -math.radians(pitch), 0.0) if pitch != 0.0 else None
        );
        # Leave the framebuffer before EndMode3D: raylib restores the screen's
        # HiDPI scale only when it ends 3D mode on the window's framebuffer.
        rlDrawRenderBatchActive();
        rlDisableFramebuffer();
        EndMode3D();
        rlViewport(i32(0), i32(0), GetRenderWidth(), GetRenderHeight());
        hud.pics["icon3d"] = HudPic(id=self.target.color, width=ICON_RESOLUTION, height=ICON_RESOLUTION);
        # Framebuffer images are stored bottom row first.
        hud.blit("icon3d", x, y, size, size, v0=1.0, v1=0.0);
        rlDrawRenderBatchActive();
        # The target owns this texture; the HUD must not unload it.
        hud.pics.pop("icon3d");
    }

    def close() {
        for renderer in self.ammo.values() {
            renderer.close();
        }
        self.ammo = {};
        if self.armor is not None {
            self.armor.close();
        }
        if self.head is not None {
            self.head.close();
        }
        self.armor = None;
        self.head = None;
        self.target.release();
    }
}
