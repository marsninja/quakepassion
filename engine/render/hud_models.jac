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
import from .hud { HudRenderer, HudPic, HudStatus }
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
        random_state: int = 1,
        head_start_yaw: float = 180.0,
        head_end_yaw: float = 180.0,
        head_start_pitch: float = 0.0,
        head_end_pitch: float = 0.0,
        head_start_time: float = 0.0,
        head_end_time: float = 0.0,
        last_health: int = -1,
        damage_time: float = -100.0;

    def ready() -> bool {
        return self.head is not None;
    }

    def random() -> float {
        self.random_state = (self.random_state * 48271) % 2147483647;
        return float(self.random_state) / 2147483647.0;
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

    """CG_DrawStatusBarHead: glance to a new angle every 0.1-2.1 s, easing
    there, and kick toward the damage when hurt, growing for a moment."""
    def draw_head(hud: HudRenderer, status: HudStatus, x: float, scale: float, width: int, height: int) {
        head = self.head;
        if head is None {
            return;
        }
        now = status.clock;
        if self.last_health >= 0 and status.health < self.last_health {
            self.damage_time = now;
        }
        self.last_health = status.health;
        size = 48.0 * 1.25;
        if now - self.damage_time < 0.5 {
            frac = (now - self.damage_time) / 0.5;
            size = 48.0 * 1.25 * (1.5 - frac * 0.5);
            stretch = size - 48.0 * 1.25;
            x -= stretch * 0.5 * scale;
            self.head_start_yaw = 180.0;
            self.head_end_yaw = 180.0 + 20.0 * math.cos((self.random() * 2.0 - 1.0) * math.pi);
            self.head_end_pitch = 5.0 * math.cos((self.random() * 2.0 - 1.0) * math.pi);
            self.head_start_time = now;
            self.head_end_time = now + 0.1 + self.random() * 2.0;
        } elif now >= self.head_end_time {
            self.head_start_yaw = self.head_end_yaw;
            self.head_start_pitch = self.head_end_pitch;
            self.head_start_time = self.head_end_time;
            self.head_end_time = now + 0.1 + self.random() * 2.0;
            self.head_end_yaw = 180.0 + 20.0 * math.cos((self.random() * 2.0 - 1.0) * math.pi);
            self.head_end_pitch = 5.0 * math.cos((self.random() * 2.0 - 1.0) * math.pi);
        }
        if self.head_start_time > now {
            self.head_start_time = now;
        }
        span = max(0.001, self.head_end_time - self.head_start_time);
        frac = max(0.0, min(1.0, (now - self.head_start_time) / span));
        frac = frac * frac * (3.0 - 2.0 * frac);
        yaw = self.head_start_yaw + (self.head_end_yaw - self.head_start_yaw) * frac;
        pitch = self.head_start_pitch + (self.head_end_pitch - self.head_start_pitch) * frac;
        self.icon(hud, head, self.head_origin, yaw, pitch, x, float(height) - size * scale, size * scale, width, height, now);
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
        EndMode3D();
        rlDisableFramebuffer();
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
