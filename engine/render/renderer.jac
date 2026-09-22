"""Raylib window, camera, overlay, and graybox rendering boundary.

BSP polygon rendering lives beside this module in quake.jac. Both use native
C FFI to the staged vendor/raylib library. Small camera and color structs
cross the FFI by value; sized casts specify the C parameter widths.

Method and ability bodies live in impl/renderer.impl.jac.
"""

import from vendor.raylib {
    def DrawLine3D(startPos: Vector3, endPos: Vector3, color: Color) -> None;  def DrawRectangle(
        x: i32, y: i32, width: i32, height: i32, color: Color
    ) -> None;  def SetTargetFPS(fps: i32) -> None;  def SetExitKey(key: i32) -> None;  def rlSetClipPlanes(
        nearPlane: f64, farPlane: f64
    ) -> None;  obj Color {
        has r: u8,
            g: u8,
            b: u8,
            a: u8;
    }  obj Vector3 {
        has x: f32,
            y: f32,
            z: f32;
    }  obj Camera3D {
        has position: Vector3,
            target: Vector3,
            up: Vector3,
            fovy: f32,
            projection: i32;
    }  def InitWindow(width: i32, height: i32, title: str) -> None;  def IsWindowReady -> bool;  def WindowShouldClose -> bool;  def CloseWindow -> None;  def BeginDrawing -> None;  def EndDrawing -> None;  def GetFrameTime -> f32;  def TakeScreenshot(
        fileName: str
    ) -> None;  def DrawFPS(posX: i32, posY: i32) -> None;  def ClearBackground(
        color: Color
    ) -> None;  def BeginMode3D(camera: Camera3D) -> None;  def EndMode3D -> None;  def DrawCube(
        position: Vector3, width: f32, height: f32, length: f32, color: Color
    ) -> None;  def DrawCubeWires(
        position: Vector3, width: f32, height: f32, length: f32, color: Color
    ) -> None;  def DrawText(
        text: str, posX: i32, posY: i32, fontSize: i32, color: Color
    ) -> None;
}

import from ..world.chthon { LightningEvent, HasLightning, Electrode, electrode_point }
import from ..world.doors { Door }
import from ..world.combat {
    CombatState,
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    selected_weapon
}
import from ..math.vec3 { Vec3, forward_from }
import from ..world.world { World, Area, Surface }


glob FOV_DEGREES: float = 72.0,
     CAMERA_PERSPECTIVE: int = 0;


obj Renderer {
    has fov: float = 72.0,
        frame_limit: int = 0,
        width: int = 1280,
        height: int = 720,
        title: str = "QuakePassion — Quake level viewer";

    def set_frame_limit(fps: int);
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
    def draw_opponents(world: World, height: float);
    def draw_message(message: str);
    def draw_loading(name: str);
    def draw_combat(state: CombatState, arena: bool, ammo: int = -1);
    def draw_projectiles(world: World, hidden_effects: list[str] = []);
    def draw_terminal(message: str);
    def draw_keys(message: str);
    def draw_status(health: int, armor: int, shells: int = 0);
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
