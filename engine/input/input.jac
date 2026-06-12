"""Input sampling. The only place that reads raylib input state; everything
downstream consumes an Intent.

Mouse-look follows the raylib_shooter's battle-tested pattern for quirky
platforms (WSLg especially): the cursor starts free and is captured on
click or Tab; deltas come from absolute position diffs with a warmup
period and a spike clamp, not get_mouse_delta. Arrow keys always work."""

import pyray as rl;

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

glob _mouse: MouseState = MouseState();


def mouse_captured() -> bool {
    return _mouse.captured;
}


def _capture() {
    rl.disable_cursor();
    _mouse.captured = True;
    _mouse.warmup = 10;
}


def _release() {
    rl.enable_cursor();
    _mouse.captured = False;
}


def sample_intent(dt: float) -> Intent {
    mv = Vec3();
    if rl.is_key_down(rl.KEY_W) {
        mv.y += 1.0;
    }
    if rl.is_key_down(rl.KEY_S) {
        mv.y -= 1.0;
    }
    if rl.is_key_down(rl.KEY_D) {
        mv.x += 1.0;
    }
    if rl.is_key_down(rl.KEY_A) {
        mv.x -= 1.0;
    }
    if rl.is_key_down(rl.KEY_SPACE) {
        mv.z += 1.0;
    }
    if rl.is_key_down(rl.KEY_LEFT_SHIFT) {
        mv.z -= 1.0;
    }

    # arrow keys always steer, captured or not
    yaw = 0.0;
    pitch = 0.0;
    if rl.is_key_down(rl.KEY_LEFT) {
        yaw += KEY_TURN_SPEED * dt;
    }
    if rl.is_key_down(rl.KEY_RIGHT) {
        yaw -= KEY_TURN_SPEED * dt;
    }
    if rl.is_key_down(rl.KEY_UP) {
        pitch += KEY_TURN_SPEED * dt;
    }
    if rl.is_key_down(rl.KEY_DOWN) {
        pitch -= KEY_TURN_SPEED * dt;
    }

    # capture lifecycle: click or Tab grabs the mouse, Tab releases
    if rl.is_key_pressed(rl.KEY_TAB) {
        if _mouse.captured {
            _release();
        } else {
            _capture();
        }
    }
    if not _mouse.captured and rl.is_mouse_button_pressed(rl.MOUSE_BUTTON_LEFT) {
        _capture();
    }

    if _mouse.captured {
        mx = float(rl.get_mouse_x());
        my = float(rl.get_mouse_y());
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
        toggle_culling=rl.is_key_pressed(rl.KEY_C),
        toggle_overlay=rl.is_key_pressed(rl.KEY_F3)
    );
}
