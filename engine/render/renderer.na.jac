"""The raylib wall. Every rendering call in the engine lives here — swapping
the graphics backend later touches this file and nothing else.

Native pathway: raylib is bound through Jac's C-FFI by its logical name. The
shared library is staged at `vendor/libraylib.so`, so the import is
`from vendor.raylib` — the native linker records a `$ORIGIN/vendor/libraylib.so`
DT_NEEDED and the loader resolves it beside the binary regardless of cwd.

raylib's small math structs (`Color`, `Vector3`, `Camera3D`) are declared as
`obj` blocks inside the import and passed/returned **by value**: the native
backend lowers them through the platform C struct ABI (System V AMD64 eightbyte
classification / AArch64 AAPCS, byval/sret), so the headline 3D API
(`BeginMode3D(Camera3D)`, `DrawCube(Vector3, …, Color)`, `ClearBackground(Color)`)
crosses the FFI cleanly — no scalar rlgl, no hand-rolled camera."""

import from vendor.raylib {
    obj Color { has r: u8, g: u8, b: u8, a: u8; }
    obj Vector3 { has x: f32, y: f32, z: f32; }
    obj Camera3D {
        has position: Vector3,
            target: Vector3,
            up: Vector3,
            fovy: f32,
            projection: i32;
    }

    def InitWindow(width: i32, height: i32, title: str) -> None;
    def SetTargetFPS(fps: i32) -> None;
    def WindowShouldClose -> bool;
    def CloseWindow -> None;
    def BeginDrawing -> None;
    def EndDrawing -> None;
    def GetFrameTime -> f32;
    def TakeScreenshot(fileName: str) -> None;
    def DrawFPS(posX: i32, posY: i32) -> None;
    def ClearBackground(color: Color) -> None;
    def BeginMode3D(camera: Camera3D) -> None;
    def EndMode3D -> None;
    def DrawCube(
        position: Vector3, width: f32, height: f32, length: f32, color: Color
    ) -> None;
    def DrawCubeWires(
        position: Vector3, width: f32, height: f32, length: f32, color: Color
    ) -> None;
    def DrawText(
        text: str, posX: i32, posY: i32, fontSize: i32, color: Color
    ) -> None;
}

import from ..math.vec3 { Vec3, forward_from }
import from ..world.world { World, Area, Surface }


glob FOV_DEGREES: float = 72.0,
     CAMERA_PERSPECTIVE: int = 0;


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

    """Begin a frame: clear and install a z-up perspective camera. The camera is
    raylib's own `Camera3D` with up = +Z (Quake's convention) and a target one
    forward-vector ahead of the eye — exactly the view the @sv renderer built."""
    def begin_frame(eye: Vec3, yaw: float, pitch: float) {
        BeginDrawing();
        ClearBackground(Color(r=10, g=8, b=6, a=255));
        target = eye.add(forward_from(yaw, pitch));
        cam = Camera3D(
            position=Vector3(x=eye.x, y=eye.y, z=eye.z),
            target=Vector3(x=target.x, y=target.y, z=target.z),
            up=Vector3(x=0.0, y=0.0, z=1.0),
            fovy=FOV_DEGREES,
            projection=CAMERA_PERSPECTIVE
        );
        BeginMode3D(cam);
    }

    """Draw an area's graybox surfaces as solid cubes with wireframe edges."""
    def draw_area(area: Area) {
        for s in area.surfaces {
            pos = Vector3(x=s.center.x, y=s.center.y, z=s.center.z);
            face = Color(r=s.color[0], g=s.color[1], b=s.color[2], a=255);
            edge_c = Color(
                r=int(s.color[0] * 0.55),
                g=int(s.color[1] * 0.55),
                b=int(s.color[2] * 0.55),
                a=255
            );
            DrawCube(pos, s.size.x, s.size.y, s.size.z, face);
            DrawCubeWires(pos, s.size.x, s.size.y, s.size.z, edge_c);
        }
    }

    """End the 3D pass; raylib restores 2D screen space for overlays."""
    def end_scene() {
        EndMode3D();
    }

    def draw_overlay(lines: list[str]) {
        DrawFPS(12, 12);
        amber = Color(r=255, g=184, b=107, a=255);
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
