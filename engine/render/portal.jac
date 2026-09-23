"""An offscreen view through a Q3 portal or mirror. The view renders into its
own framebuffer before the main view, with the near plane tilted onto the
portal plane (an oblique projection standing in for Q3's glClipPlane) so
nothing behind the portal camera shows. A mirror's image is flipped left to
right, and its faces wind the other way."""
import from .viewweapon { Matrix, rlGetMatrixProjection, rlSetMatrixProjection }
import from vendor.raylib {
    def rlLoadFramebuffer() -> u32;  def rlLoadTextureDepth(
        width: i32, height: i32, useRenderBuffer: bool
    ) -> u32;  def rlFramebufferAttach(
        fboId: u32, texId: u32, attachType: i32, texType: i32, mipLevel: i32
    ) -> None;  def rlFramebufferComplete(id: u32) -> bool;  def rlEnableFramebuffer(
        id: u32
    ) -> None;  def rlDisableFramebuffer() -> None;  def rlUnloadFramebuffer(
        id: u32
    ) -> None;  def rlClearColor(r: u8, g: u8, b: u8, a: u8) -> None;  def rlClearScreenBuffers() -> None;  def rlGetMatrixModelview() -> Matrix;  def rlSetCullFace(
        mode: i32
    ) -> None;  def GetRenderWidth() -> i32;  def GetRenderHeight() -> i32;  def rlViewport(
        x: i32, y: i32, width: i32, height: i32
    ) -> None;
}
import from .quake { rlDrawRenderBatchActive, rlLoadTexture, rlTextureParameters, rlUnloadTexture }
import from .renderer { Camera3D, Vector3, BeginMode3D, EndMode3D, rlSetClipPlanes }
import from .quake { QuakeRenderer }
import from .models { ModelScene }
import from .effects { EffectScene }
import from ..world.world { World }
import from ..world.level { Level }
import from ..world.portals { portal_view, surface_plane }
import from ..math.vec3 { Vec3, forward_from, right_from }
import math;

obj PortalTarget {
    has frame: int = 0,
        color: int = 0,
        depth: int = 0,
        width: int = 0,
        height: int = 0;

    """Make (or remake, when the window size changed) the framebuffer."""
    def prepare() -> bool {
        return self.prepare_size(int(GetRenderWidth()), int(GetRenderHeight()));
    }

    """Make (or remake) a framebuffer of the given size."""
    def prepare_size(width: int, height: int) -> bool {
        if self.frame != 0 and width == self.width and height == self.height {
            return True;
        }
        self.release();
        if width <= 0 or height <= 0 {
            return False;
        }
        frame = rlLoadFramebuffer();
        color = rlLoadTexture(bytes(width * height * 4), i32(width), i32(height), i32(7), i32(1));
        depth = rlLoadTextureDepth(i32(width), i32(height), True);
        rlTextureParameters(color, i32(10241), i32(9729));
        rlTextureParameters(color, i32(10240), i32(9729));
        rlTextureParameters(color, i32(10242), i32(33071));
        rlTextureParameters(color, i32(10243), i32(33071));
        rlEnableFramebuffer(frame);
        rlFramebufferAttach(frame, color, i32(0), i32(100), i32(0));
        rlFramebufferAttach(frame, depth, i32(100), i32(200), i32(0));
        complete = rlFramebufferComplete(frame);
        rlDisableFramebuffer();
        self.frame = int(frame);
        self.color = int(color);
        self.depth = int(depth);
        self.width = width;
        self.height = height;
        if not complete {
            self.release();
            return False;
        }
        return True;
    }

    def release() {
        if self.frame != 0 {
            rlUnloadFramebuffer(u32(self.frame));
            rlUnloadTexture(u32(self.color));
            self.frame = 0;
            self.color = 0;
            self.depth = 0;
        }
    }

    """Start drawing the view from `origin` along `forward` with `up`, clipped
    to the side of the plane (normal, dist) that the normal faces."""
    def begin(fov: float, origin: Vec3, forward: Vec3, up: Vec3, mirror: bool, normal: Vec3, dist: float) {
        rlDrawRenderBatchActive();
        rlEnableFramebuffer(u32(self.frame));
        rlClearColor(u8(0), u8(0), u8(0), u8(255));
        rlClearScreenBuffers();
        target = origin.add(forward);
        rlSetClipPlanes(1.0, 32768.0);
        BeginMode3D(
            Camera3D(
                position=Vector3(x=f32(origin.x), y=f32(origin.y), z=f32(origin.z)),
                target=Vector3(x=f32(target.x), y=f32(target.y), z=f32(target.z)),
                up=Vector3(x=f32(up.x), y=f32(up.y), z=f32(up.z)),
                fovy=f32(fov),
                projection=i32(0)
            )
        );
        view = rlGetMatrixModelview();
        projection = rlGetMatrixProjection();
        oblique_near_plane(projection, view, normal, dist);
        if mirror {
            projection.m0 = -projection.m0;
            projection.m4 = -projection.m4;
            projection.m8 = -projection.m8;
            projection.m12 = -projection.m12;
            rlDrawRenderBatchActive();
            rlSetCullFace(i32(0));
        }
        rlSetMatrixProjection(projection);
    }

    def finish() {
        EndMode3D();
        rlSetCullFace(i32(1));
        rlDisableFramebuffer();
    }
}

"""Lengyel's oblique near plane: tilt the projection's near plane onto the
eye-space form of the world plane, so geometry on its back side is clipped.
Skipped when the plane passes (nearly) through the eye, where the near plane
already does the job."""
def oblique_near_plane(projection: Matrix, view: Matrix, normal: Vec3, dist: float) {
    point = normal.scale(dist);
    nx = float(view.m0) * normal.x + float(view.m4) * normal.y + float(view.m8) * normal.z;
    ny = float(view.m1) * normal.x + float(view.m5) * normal.y + float(view.m9) * normal.z;
    nz = float(view.m2) * normal.x + float(view.m6) * normal.y + float(view.m10) * normal.z;
    px = float(view.m0) * point.x + float(view.m4) * point.y + float(view.m8) * point.z + float(view.m12);
    py = float(view.m1) * point.x + float(view.m5) * point.y + float(view.m9) * point.z + float(view.m13);
    pz = float(view.m2) * point.x + float(view.m6) * point.y + float(view.m10) * point.z + float(view.m14);
    cw = -(nx * px + ny * py + nz * pz);
    if cw > -1.0 {
        return;
    }
    qx = ((1.0 if nx > 0.0 else -1.0) + float(projection.m8)) / float(projection.m0);
    qy = ((1.0 if ny > 0.0 else -1.0) + float(projection.m9)) / float(projection.m5);
    qz = -1.0;
    qw = (1.0 + float(projection.m10)) / float(projection.m14);
    scale = 2.0 / (nx * qx + ny * qy + nz * qz + cw * qw);
    projection.m2 = f32(nx * scale);
    projection.m6 = f32(ny * scale);
    projection.m10 = f32(nz * scale + 1.0);
    projection.m14 = f32(cw * scale);
}

"""tr_main.c R_SortDrawSurfs: before the main view, render the view through the
first on-screen portal or mirror surface (only one a frame) and hand it to the
world renderer. A mirror always renders; a portal only within its shader's
portalRange. Returns whether a view was rendered."""
def draw_portal_view(
    target: PortalTarget,
    level: Level,
    world: World,
    quake: QuakeRenderer,
    models: ModelScene,
    effects: EffectScene,
    faces: list[int],
    eye: Vec3,
    yaw: float,
    pitch: float,
    fov: float,
    seconds: float
) -> bool {
    quake.portal_image = 0;
    if level.bsp.game != "q3" or not level.portal_ranges {
        return False;
    }
    forward = forward_from(yaw, pitch);
    left = right_from(yaw).scale(-1.0);
    up = forward.cross(left).normalized();
    for index in sorted(faces) {
        face = level.bsp.faces[index];
        if face.texture not in level.portal_ranges or face.hidden or not face.vertices {
            continue;
        }
        plane = surface_plane(face);
        if plane[0].dot(eye) - plane[1].x <= 0.0 {
            continue;
        }
        ahead = False;
        nearest = 1000000.0;
        for v in face.vertices {
            if forward.dot(v.sub(eye)) > 0.0 {
                ahead = True;
            }
            nearest = min(nearest, v.sub(eye).length());
        }
        if not ahead {
            continue;
        }
        view = portal_view(world, face, eye, forward, left, up, seconds);
        if view is None {
            continue;
        }
        if not view.mirror and nearest > level.portal_ranges[face.texture] {
            continue;
        }
        if not target.prepare() {
            return False;
        }
        through = level.visible(world, view.pvs, False);
        target.begin(fov, view.origin, view.forward, view.up, view.mirror, view.clip_normal, view.clip_dist);
        quake.view_forward = view.forward;
        quake.draw(level, through, view.origin);
        view_yaw = math.atan2(view.forward.y, view.forward.x);
        view_pitch = math.asin(max(-1.0, min(1.0, view.forward.z)));
        models.draw(world, view.origin, seconds, culling=False, yaw=view_yaw, pitch=view_pitch, lighting=level.lighting, fogs=level.bsp.fogs, fog_image=quake.fog_image);
        effects.draw(world, view.origin, view_yaw, view_pitch, lighting=level.lighting);
        target.finish();
        quake.portal_image = target.color;
        quake.portal_normal = plane[0];
        quake.portal_dist = plane[1].x;
        quake.portal_width = float(target.width);
        quake.portal_height = float(target.height);
        return True;
    }
    return False;
}
