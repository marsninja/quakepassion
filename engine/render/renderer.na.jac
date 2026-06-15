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
crosses the FFI cleanly — no scalar rlgl, no hand-rolled camera.

Method and ability bodies live in impl/renderer.na.impl.jac."""

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

    def open_window();
    def should_close() -> bool;
    def frame_time() -> float;

    """Begin a frame: clear and install a z-up perspective camera. The camera is
    raylib's own `Camera3D` with up = +Z (Quake's convention) and a target one
    forward-vector ahead of the eye — exactly the view the @sv renderer built."""
    def begin_frame(eye: Vec3, yaw: float, pitch: float);

    """Draw an area's graybox surfaces as solid cubes with wireframe edges."""
    def draw_area(area: Area);

    """End the 3D pass; raylib restores 2D screen space for overlays."""
    def end_scene();

    def draw_overlay(lines: list[str]);
    def end_frame();
    def screenshot(path: str);
    def close();
}


"""Draw dispatch as graph traversal: visit exactly the areas VisPass collected
and hand each to the renderer. Lives in the render layer (not world) so its
`renderer` field is a concrete `Renderer` — no `any` — without creating a
world->renderer import cycle. Every raylib call stays behind the Renderer wall."""
walker RenderPass {
    has targets: list[Area] = [],
        renderer: Renderer = Renderer(),
        drawn: int = 0;

    can start with World entry;
    can draw with Area entry;
}
