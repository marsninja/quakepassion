"""Input sampling. The only place that reads raylib input state; everything
downstream consumes an Intent.

Mouse-look follows the raylib_shooter's battle-tested pattern for quirky
platforms (WSLg especially): the cursor starts free and is captured on
click or the console key (`), which also releases it (Tab holds the
scoreboard); deltas come from absolute position diffs with a warmup
period and a spike clamp, not GetMouseDelta. Arrow keys always work.

Native pathway: raylib bound through the C-FFI by logical name from the
staged sibling library (see renderer.jac for the linking note).

Function bodies live in impl/input.impl.jac."""

import from vendor.raylib {
    def IsKeyDown(key: i32) -> bool;  def IsKeyPressed(key: i32) -> bool;  def GetMouseWheelMove -> f32;  def IsMouseButtonDown(
        button: i32
    ) -> bool;  def IsMouseButtonPressed(button: i32) -> bool;  def GetMouseX -> i32;  def GetMouseY -> i32;  def DisableCursor -> None;  def EnableCursor -> None;
}

import from ..math.vec3 { Vec3 }


obj Intent {
    has move: Vec3 = Vec3(),
        look_yaw: float = 0.0,
        look_pitch: float = 0.0,
        toggle_culling: bool = False,
        toggle_overlay: bool = False,
        toggle_walk: bool = False,
        jump: bool = False,
        jump_held: bool = False,
        crouch: bool = False,
        fire: bool = False,
        weapon: int = 0,
        weapon_step: int = 0,
        use_item: bool = False,
        next_item: bool = False,
        prev_item: bool = False,
        scores: bool = False,
        help: bool = False,
        inventory: bool = False;
}


obj MouseState {
    has captured: bool = False,
        warmup: int = 0,
        prev_x: float = 0.0,
        prev_y: float = 0.0;
}


glob MOUSE_SENSITIVITY: float = 0.0022,
     KEY_TURN_SPEED: float = 2.2,
     SPIKE_LIMIT: float = 150.0;

# raylib key / button codes (raylib.h)
glob KEY_W: i32 = 87,
     KEY_A: i32 = 65,
     KEY_S: i32 = 83,
     KEY_D: i32 = 68,
     KEY_C: i32 = 67,
     KEY_F3: i32 = 292,
     KEY_SPACE: i32 = 32,
     KEY_LEFT_SHIFT: i32 = 340,
     KEY_RIGHT: i32 = 262,
     KEY_LEFT: i32 = 263,
     KEY_DOWN: i32 = 264,
     KEY_UP: i32 = 265,
     KEY_TAB: i32 = 258,
     MOUSE_LEFT: i32 = 0;

glob _mouse: MouseState = MouseState();


def mouse_captured() -> bool;
def _capture();
def _release();
def sample_intent(
    dt: float, sensitivity: float = 0.0022, invert_y: bool = False
) -> Intent;
