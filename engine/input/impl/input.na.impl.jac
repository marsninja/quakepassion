"""Implementations for the input module: mouse-capture lifecycle and the
per-frame intent sampler. Declarations (and the raylib import) live in
input.na.jac."""

impl mouse_captured() -> bool {
    return _mouse.captured;
}

impl _capture() {
    DisableCursor();
    _mouse.captured = True;
    _mouse.warmup = 10;
}

impl _release() {
    EnableCursor();
    _mouse.captured = False;
}

impl sample_intent(dt: float) -> Intent {
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
