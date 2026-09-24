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
    ) -> None;  obj rlVertexBuffer;  obj rlDrawCall;  obj rlRenderBatch {
        has bufferCount: i32,
            currentBuffer: i32,
            vertexBuffer: ptr[rlVertexBuffer],
            draws: ptr[rlDrawCall],
            drawCounter: i32,
            currentDepth: f32;
    }  def rlLoadRenderBatch(numBuffers: i32, bufferElements: i32) -> rlRenderBatch;  def rlUnloadRenderBatch(
        batch: rlRenderBatch
    ) -> None;  def rlSetRenderBatchActive(batch: &mut Pinned[rlRenderBatch] | None) -> None;
}

import math;
import from ..world.particles { HasParticle, ImpactParticle, HasTrail, ShotTrail }
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
import from ..math.vec3 { Vec3, forward_from, right_from }
import from ..world.world { World, Area, Surface }


glob FOV_DEGREES: float = 72.0,
     CAMERA_PERSPECTIVE: int = 0;


# rlgl's default batch has one vertex buffer, so every flush refills the
# buffer the GPU may still be drawing from and waits for it. Rotating through
# several lets a flush fill one the GPU has finished with.
glob BATCH_BUFFERS: int = 64,
     BATCH_ELEMENTS: int = 2048;

obj Renderer {
    has fov: float = 72.0,
        frame_limit: int = 0,
        width: int = 1280,
        height: int = 720,
        title: str = "QuakePassion — Quake level viewer",
        batch: Pinned[rlRenderBatch] | None = None;

    def set_frame_limit(fps: int);
    def open_window();
    def should_close() -> bool;
    def frame_time() -> float;
    """Begin a frame: clear and install a z-up perspective camera. The camera is
    raylib's own `Camera3D` with up = +Z (Quake's convention) and a target one
    forward-vector ahead of the eye — exactly the view the @sv renderer built."""
    def begin_frame(eye: Vec3, yaw: float, pitch: float, roll: float = 0.0);

    """Draw an area's graybox surfaces as solid cubes with wireframe edges."""
    def draw_area(area: Area);

    """End the 3D pass; raylib restores 2D screen space for overlays."""
    def end_scene();

    def draw_overlay(lines: list[str]);
    def draw_opponents(world: World, height: float);
    def draw_message(message: str);
    def draw_loading(name: str);
    def draw_combat(state: CombatState, arena: bool, ammo: int = -1, score: str = "");
    def draw_scoreboard(title: str, lines: list[str], footer: str);
    def draw_projectiles(world: World, hidden_effects: list[str] = []);
    def draw_terminal(message: str);
    def draw_finale(text: str, prompt: str);
    def draw_keys(message: str);
    def draw_status(health: int, armor: int, shells: int = 0, arena: bool = False);
    """Beside an original status bar: the crosshair, the hit marker and the
    arena score line."""
    def draw_aim(state: CombatState, crosshair: bool, score: str);
    def draw_tint(r: int, g: int, b: int, a: int);
    def draw_powerups(lines: list[str]);
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
