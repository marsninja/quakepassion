"""The raylib wall. Every rendering call in the engine lives here — swapping
the graphics backend later touches this file and nothing else.

Native pathway: raylib is bound through Jac's C-FFI by its logical name. The
shared library is staged at `vendor/libraylib.so`, so the import is
`from vendor.raylib` — the native linker records a `$ORIGIN/vendor/libraylib.so`
DT_NEEDED and the loader resolves it beside the binary regardless of cwd.

Only scalar / small-struct entry points are bound: the 3D pipeline uses raylib's
scalar rlgl immediate-mode API (rlVertex3f / rlColor4ub / rlTranslatef / ...)
rather than the by-value DrawCube(Vector3) / BeginMode3D(Camera3D) API, which
the native backend does not lower to the C ABI yet. The one small struct we do
pass by value is `Color` (4×u8 = 4 bytes), handed across as a single packed u32
in the integer register the SysV ABI uses for it — that is how draw_text gets a
color without a by-value multi-field struct."""

import from vendor.raylib {
    def InitWindow(width: i32, height: i32, title: str) -> None;
    def SetTargetFPS(fps: i32) -> None;
    def WindowShouldClose -> bool;
    def CloseWindow -> None;
    def BeginDrawing -> None;
    def EndDrawing -> None;
    def GetFrameTime -> f32;
    def TakeScreenshot(fileName: str) -> None;
    def DrawFPS(posX: i32, posY: i32) -> None;
    def DrawText(text: str, posX: i32, posY: i32, fontSize: i32, color: u32) -> None;
    def rlClearColor(r: u8, g: u8, b: u8, a: u8) -> None;
    def rlClearScreenBuffers -> None;
    def rlEnableDepthTest -> None;
    def rlMatrixMode(mode: i32) -> None;
    def rlLoadIdentity -> None;
    def rlPushMatrix -> None;
    def rlPopMatrix -> None;
    def rlTranslatef(x: f32, y: f32, z: f32) -> None;
    def rlRotatef(angle: f32, x: f32, y: f32, z: f32) -> None;
    def rlFrustum(
        left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64
    ) -> None;
    def rlOrtho(
        left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64
    ) -> None;
    def rlBegin(mode: i32) -> None;
    def rlEnd -> None;
    def rlVertex3f(x: f32, y: f32, z: f32) -> None;
    def rlColor4ub(r: u8, g: u8, b: u8, a: u8) -> None;
    def rlSetLineWidth(width: f32) -> None;
    def rlDrawRenderBatchActive -> None;
}

import from ..math.vec3 { Vec3 }
import from ..world.world { World, Area, Surface }


glob RL_MODELVIEW: int = 0x1700,
     RL_PROJECTION: int = 0x1701,
     RL_LINES: int = 0x0001,
     RL_TRIANGLES: int = 0x0004,
     RAD2DEG: float = 57.29577951308232,
     FOV_DEGREES: float = 72.0;


"""Pack an (r,g,b,a) color into the little-endian u32 raylib's Color struct is
(r low byte). Lets draw_text take a color through a single integer register."""
def rgba(r: int, g: int, b: int, a: int) -> int {
    return r + g * 256 + b * 65536 + a * 16777216;
}

"""Scale a 0-255 channel by a percentage (cheap per-face shading)."""
def shade(c: int, pct: int) -> int {
    v = c * pct // 100;
    if v < 255 {
        return v;
    }
    return 255;
}

"""Emit one quad (corners p0->p1->p2->p3, CCW) as two triangles."""
def quad(
    p0: float, p1: float, p2: float,
    p3: float, p4: float, p5: float,
    p6: float, p7: float, p8: float,
    p9: float, p10: float, p11: float
) {
    rlVertex3f(p0, p1, p2);
    rlVertex3f(p3, p4, p5);
    rlVertex3f(p6, p7, p8);
    rlVertex3f(p0, p1, p2);
    rlVertex3f(p6, p7, p8);
    rlVertex3f(p9, p10, p11);
}


obj Renderer {
    has width: int = 1280,
        height: int = 720,
        title: str = "QuakePassion — Phase 1: First Light";

    def open_window() {
        InitWindow(self.width, self.height, self.title);
        SetTargetFPS(120);
    }

    def should_close() -> bool {
        return WindowShouldClose();
    }

    def frame_time() -> float {
        return GetFrameTime();
    }

    """Begin a frame: clear, enable depth, and install the z-up perspective
    camera. The view transform reproduces raylib's Camera3D(up=+Z) exactly:
    R = Rx(-(90+pitch)) · Rz(90-yaw), then translate by -eye. (Derived to
    zero error against the by-value lookat the @sv renderer used.)"""
    def begin_frame(eye: Vec3, yaw: float, pitch: float) {
        BeginDrawing();
        rlClearColor(10, 8, 6, 255);
        rlClearScreenBuffers();
        rlEnableDepthTest();

        near = 0.05;
        far_plane = 4000.0;
        aspect = float(self.width) / float(self.height);
        top = near * 0.72654253;          # tan(FOV/2) for 72° vertical FOV
        right = top * aspect;
        rlMatrixMode(RL_PROJECTION);
        rlLoadIdentity();
        rlFrustum(-right, right, -top, top, near, far_plane);
        rlMatrixMode(RL_MODELVIEW);
        rlLoadIdentity();
        rlRotatef(-(90.0 + pitch * RAD2DEG), 1.0, 0.0, 0.0);
        rlRotatef(90.0 - yaw * RAD2DEG, 0.0, 0.0, 1.0);
        rlTranslatef(-eye.x, -eye.y, -eye.z);
    }

    """Draw an area's graybox surfaces as shaded solid boxes."""
    def draw_area(area: Area) {
        for s in area.surfaces {
            self.draw_box(s);
        }
    }

    """One axis-aligned shaded box. Faces carry a fixed per-face brightness so
    the box reads as solid without real lighting; winding is CCW-outward to
    satisfy raylib's default back-face culling. Z is up, so the brightest face
    is the top (+z) and the darkest the bottom (-z)."""
    def draw_box(s: Surface) {
        hx = s.size.x * 0.5;
        hy = s.size.y * 0.5;
        hz = s.size.z * 0.5;
        r = s.color[0];
        g = s.color[1];
        b = s.color[2];
        rlPushMatrix();
        rlTranslatef(s.center.x, s.center.y, s.center.z);
        rlBegin(RL_TRIANGLES);

        # top (+z), brightest
        rlColor4ub(shade(r, 100), shade(g, 100), shade(b, 100), 255);
        quad(-hx, -hy, hz,  hx, -hy, hz,  hx, hy, hz,  -hx, hy, hz);
        # sides
        rlColor4ub(shade(r, 78), shade(g, 78), shade(b, 78), 255);
        quad(-hx, -hy, -hz,  hx, -hy, -hz,  hx, -hy, hz,  -hx, -hy, hz);  # -y
        quad(hx, -hy, -hz,  hx, hy, -hz,  hx, hy, hz,  hx, -hy, hz);      # +x
        rlColor4ub(shade(r, 62), shade(g, 62), shade(b, 62), 255);
        quad(hx, hy, -hz,  -hx, hy, -hz,  -hx, hy, hz,  hx, hy, hz);      # +y
        quad(-hx, hy, -hz,  -hx, -hy, -hz,  -hx, -hy, hz,  -hx, hy, hz);  # -x
        # bottom (-z), darkest
        rlColor4ub(shade(r, 42), shade(g, 42), shade(b, 42), 255);
        quad(-hx, hy, -hz,  hx, hy, -hz,  hx, -hy, -hz,  -hx, -hy, -hz);

        rlEnd();
        rlPopMatrix();
    }

    """End the 3D pass and install a pixel-space 2D ortho for overlays."""
    def end_scene() {
        rlDrawRenderBatchActive();
        rlMatrixMode(RL_PROJECTION);
        rlLoadIdentity();
        rlOrtho(0.0, float(self.width), float(self.height), 0.0, -1.0, 1.0);
        rlMatrixMode(RL_MODELVIEW);
        rlLoadIdentity();
    }

    def draw_overlay(lines: list[str]) {
        DrawFPS(12, 12);
        amber = rgba(255, 184, 107, 255);
        y = 40;
        for line in lines {
            DrawText(line, 12, y, 20, amber);
            y += 26;
        }
    }

    def end_frame() {
        EndDrawing();
    }

    def screenshot(path: str) {
        TakeScreenshot(path);
    }

    def close() {
        CloseWindow();
    }
}


"""Draw dispatch as graph traversal: visit exactly the areas VisPass collected
and hand each to the renderer. Lives in the render layer (not world) so its
`renderer` field is a concrete `Renderer` — no `any` — without creating a
world->renderer import cycle. Every raylib call stays behind the Renderer wall."""
walker RenderPass {
    has targets: list[Area] = [],
        renderer: Renderer = Renderer(),
        drawn: int = 0;

    can start with World entry {
        visit self.targets;
    }

    can draw with Area entry {
        self.renderer.draw_area(here);
        self.drawn += 1;
    }
}
