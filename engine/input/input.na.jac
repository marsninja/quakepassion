"""Input sampling. The only place that reads raylib input state; everything
downstream consumes an Intent.

Mouse-look follows the raylib_shooter's battle-tested pattern for quirky
platforms (WSLg especially): the cursor starts free and is captured on
click or Tab; deltas come from absolute position diffs with a warmup
period and a spike clamp, not GetMouseDelta. Arrow keys always work.

Native pathway: raylib bound through the C-FFI by logical name from the
staged sibling library (see renderer.na.jac for the linking note)."""

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


def mouse_captured() -> bool {
    return _mouse.captured;
}


def _capture() {
    DisableCursor();
    _mouse.captured = True;
    _mouse.warmup = 10;
}


def _release() {
    EnableCursor();
    _mouse.captured = False;
}


def sample_intent(dt: float) -> Intent {
    mv = Vec3();
    if IsKeyDown(KEY_W) {
        mv.y += 1.0;
    }
    if IsKeyDown(KEY_S) {
        mv.y -= 1.0;
    }
    if IsKeyDown(KEY_D) {
        mv.x += 1.0;
    }
    if IsKeyDown(KEY_A) {
        mv.x -= 1.0;
    }
    if IsKeyDown(KEY_SPACE) {
        mv.z += 1.0;
    }
    if IsKeyDown(KEY_LEFT_SHIFT) {
        mv.z -= 1.0;
    }

    # arrow keys always steer, captured or not
    yaw = 0.0;
    pitch = 0.0;
    if IsKeyDown(KEY_LEFT) {
        yaw += KEY_TURN_SPEED * dt;
    }
    if IsKeyDown(KEY_RIGHT) {
        yaw -= KEY_TURN_SPEED * dt;
    }
    if IsKeyDown(KEY_UP) {
        pitch += KEY_TURN_SPEED * dt;
    }
    if IsKeyDown(KEY_DOWN) {
        pitch -= KEY_TURN_SPEED * dt;
    }

    # capture lifecycle: click or Tab grabs the mouse, Tab releases
    if IsKeyPressed(KEY_TAB) {
        if _mouse.captured {
            _release();
        } else {
            _capture();
        }
    }
    if not _mouse.captured and IsMouseButtonPressed(MOUSE_LEFT) {
        _capture();
    }

    if _mouse.captured {
        mx = float(GetMouseX());
        my = float(GetMouseY());
        if _mouse.warmup > 0 {
            _mouse.warmup -= 1;
        } else {
            dx = mx - _mouse.prev_x;
            dy = my - _mouse.prev_y;
            if dx > -SPIKE_LIMIT and dx < SPIKE_LIMIT and dy > -SPIKE_LIMIT and dy < SPIKE_LIMIT {
                yaw -= dx * MOUSE_SENSITIVITY;
                pitch -= dy * MOUSE_SENSITIVITY;
            }
        }
        _mouse.prev_x = mx;
        _mouse.prev_y = my;
    }

    return Intent(
        move=mv,
        look_yaw=yaw,
        look_pitch=pitch,
        toggle_culling=IsKeyPressed(KEY_C),
        toggle_overlay=IsKeyPressed(KEY_F3)
    );
}
