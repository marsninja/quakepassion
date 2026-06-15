"""Input sampling. The only place that reads raylib input state; everything
downstream consumes an Intent.

Mouse-look follows the raylib_shooter's battle-tested pattern for quirky
platforms (WSLg especially): the cursor starts free and is captured on
click or Tab; deltas come from absolute position diffs with a warmup
period and a spike clamp, not GetMouseDelta. Arrow keys always work.

Native pathway: raylib bound through the C-FFI by logical name from the
staged sibling library (see renderer.na.jac for the linking note).

Function bodies live in impl/input.na.impl.jac."""

import from vendor.raylib {
    def IsKeyDown(key: i32) -> bool;
    def IsKeyPressed(key: i32) -> bool;
    def IsMouseButtonPressed(button: i32) -> bool;
    def GetMouseX -> i32;
    def GetMouseY -> i32;
    def DisableCursor -> None;
    def EnableCursor -> None;
}

import from ..math.vec3 { Vec3 }


obj Intent {
    has move: Vec3 = Vec3(),
        look_yaw: float = 0.0,
        look_pitch: float = 0.0,
        toggle_culling: bool = False,
        toggle_overlay: bool = False;
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
glob KEY_W: int = 87,
     KEY_A: int = 65,
     KEY_S: int = 83,
     KEY_D: int = 68,
     KEY_C: int = 67,
     KEY_F3: int = 292,
     KEY_SPACE: int = 32,
     KEY_LEFT_SHIFT: int = 340,
     KEY_RIGHT: int = 262,
     KEY_LEFT: int = 263,
     KEY_DOWN: int = 264,
     KEY_UP: int = 265,
     KEY_TAB: int = 258,
     MOUSE_LEFT: int = 0;

glob _mouse: MouseState = MouseState();


def mouse_captured() -> bool;
def _capture();
def _release();
def sample_intent(dt: float) -> Intent;
