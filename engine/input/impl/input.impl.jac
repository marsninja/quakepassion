"""Implementations for the input module: mouse-capture lifecycle and the
per-frame intent sampler. Declarations (and the raylib import) live in
input.jac."""

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

impl sample_intent(
    dt: float, sensitivity: float = 0.0022, invert_y: bool = False
) -> Intent {
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

    # capture lifecycle: a click or the console key (`) grabs the mouse, the
    # console key or Escape's menu releases it; Tab is the scoreboard (Q2's
    # inventory).
    if IsKeyPressed(i32(96)) {
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
            if dx > -SPIKE_LIMIT
                and dx < SPIKE_LIMIT
                and dy > -SPIKE_LIMIT
                and dy < SPIKE_LIMIT {
                yaw -= dx * sensitivity;
                pitch -= dy * sensitivity * (-1.0 if invert_y else 1.0);
            }
        }
        _mouse.prev_x = mx;
        _mouse.prev_y = my;
    }

    weapon = 0;
    for slot in range(1, 11) {
        if IsKeyPressed(i32(48 + slot % 10)) {
            weapon = slot;
        }
    }
    if IsKeyPressed(i32(71)) {
        weapon = 11;
    }
    # Next / previous weapon: the mouse wheel (Q3 weapnext/weapprev) and
    # Q1's default "/" (impulse 10).
    step = 0;
    wheel = float(GetMouseWheelMove());
    if wheel > 0.0 {
        step = 1;
    } elif wheel < 0.0 {
        step = -1;
    }
    if IsKeyPressed(i32(47)) {
        step = 1;
    }
    return Intent(
        move=mv,
        look_yaw=yaw,
        look_pitch=pitch,
        toggle_culling=IsKeyPressed(KEY_C),
        toggle_overlay=IsKeyPressed(KEY_F3),
        toggle_walk=IsKeyPressed(i32(293)),
        jump=IsKeyPressed(KEY_SPACE),
        jump_held=IsKeyDown(KEY_SPACE),
        crouch=IsKeyDown(i32(341)),
        fire=_mouse.captured and _mouse.warmup == 0 and IsMouseButtonDown(MOUSE_LEFT),
        weapon=weapon,
        weapon_step=step,
        use_item=IsKeyPressed(i32(257)),
        next_item=IsKeyPressed(i32(93)),
        prev_item=IsKeyPressed(i32(91)),
        scores=IsKeyDown(KEY_TAB) or IsKeyDown(i32(290)),
        help=IsKeyPressed(i32(290)),
        inventory=IsKeyPressed(KEY_TAB)
    );
}
