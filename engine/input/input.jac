"""Input sampling. The only place that reads raylib input state; everything
downstream consumes an Intent.

Mouse-look: the cursor starts free and is captured on click or Tab.
Capture is the classic software grab — hide the cursor, measure the
offset from window center each frame, warp back to center. GLFW's
disable_cursor mode receives nothing from a physical mouse through
WSLg's input pipeline (measured: zero deltas for entire sessions), but
absolute position + set_mouse_position works everywhere. Arrow keys
always work, captured or not."""

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
        warmup: int = 0;
}


glob MOUSE_SENSITIVITY: float = 0.0022,
     KEY_TURN_SPEED: float = 2.2,
     SPIKE_LIMIT: float = 400.0;

glob _mouse: MouseState = MouseState();


def mouse_captured() -> bool {
    return _mouse.captured;
}


def _capture() {
    rl.hide_cursor();
    rl.set_mouse_position(rl.get_screen_width() // 2, rl.get_screen_height() // 2);
    _mouse.captured = True;
    _mouse.warmup = 3;
}


def _release() {
    rl.show_cursor();
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
        cx = rl.get_screen_width() // 2;
        cy = rl.get_screen_height() // 2;
        dx = float(rl.get_mouse_x() - cx);
        dy = float(rl.get_mouse_y() - cy);
        if _mouse.warmup > 0 {
            _mouse.warmup -= 1;
        } elif dx > -SPIKE_LIMIT and dx < SPIKE_LIMIT and dy > -SPIKE_LIMIT and dy < SPIKE_LIMIT {
            yaw -= dx * MOUSE_SENSITIVITY;
            pitch -= dy * MOUSE_SENSITIVITY;
        }
        rl.set_mouse_position(cx, cy);
    }

    return Intent(
        move=mv,
        look_yaw=yaw,
        look_pitch=pitch,
        toggle_culling=rl.is_key_pressed(rl.KEY_C),
        toggle_overlay=rl.is_key_pressed(rl.KEY_F3)
    );
}
