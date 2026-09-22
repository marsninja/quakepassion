"""Implementations for the render module: the Renderer wall methods and the
RenderPass walker abilities. Declarations (and the raylib import) live in
renderer.jac."""

impl Renderer.open_window() {
    InitWindow(i32(self.width), i32(self.height), self.title);
    if not IsWindowReady() {
        raise RuntimeError(
            "Cannot open the viewer window: an active graphical desktop/display is required."
        );
    }
    SetExitKey(i32(0));  # Escape belongs to the level menu.
    # Default to uncapped rendering; a user-selected limit only paces frames.
    # Simulation keeps its independent fixed timestep.
    self.set_frame_limit(self.frame_limit);
}

impl Renderer.should_close() -> bool {
    return WindowShouldClose();
}

impl Renderer.frame_time() -> float {
    return GetFrameTime();
}

impl Renderer.begin_frame(eye: Vec3, yaw: float, pitch: float) {
    BeginDrawing();
    ClearBackground(Color(r=10, g=8, b=6, a=255));
    target = eye.add(forward_from(yaw, pitch));
    cam = Camera3D(
        position=Vector3(x=f32(eye.x), y=f32(eye.y), z=f32(eye.z)),
        target=Vector3(x=f32(target.x), y=f32(target.y), z=f32(target.z)),
        up=Vector3(x=0.0, y=0.0, z=1.0),
        fovy=f32(self.fov),
        projection=i32(CAMERA_PERSPECTIVE)
    );
    rlSetClipPlanes(f64(1.0), f64(32768.0));
    BeginMode3D(cam);
}

impl Renderer.draw_area(area: Area) {
    for s in area.surfaces {
        pos = Vector3(x=f32(s.center.x), y=f32(s.center.y), z=f32(s.center.z));
        face = Color(r=u8(s.color[0]), g=u8(s.color[1]), b=u8(s.color[2]), a=255);
        edge_c = Color(
            r=u8(int(s.color[0] * 0.55)),
            g=u8(int(s.color[1] * 0.55)),
            b=u8(int(s.color[2] * 0.55)),
            a=255
        );
        DrawCube(pos, f32(s.size.x), f32(s.size.y), f32(s.size.z), face);
        DrawCubeWires(pos, f32(s.size.x), f32(s.size.y), f32(s.size.z), edge_c);
    }
}

impl Renderer.end_scene() {
    EndMode3D();
}

impl Renderer.draw_overlay(lines: list[str]) {
    DrawFPS(12, 12);
    amber = Color(r=255, g=184, b=107, a=255);
    y = 40;
    for line in lines {
        DrawText(line, 12, i32(y), 20, amber);
        y += 26;
    }
}

impl Renderer.end_frame() {
    EndDrawing();
}

impl Renderer.draw_status(health: int, armor: int, shells: int = 0) {
    color = Color(r=255, g=220, b=160, a=255);
    DrawText(
        "HEALTH "
            + str(health)
            + "    ARMOR "
            + str(armor)
            + "    SHELLS "
            + str(shells),
        20,
        i32(self.height - 42),
        24,
        color
    );
    if health <= 0 {
        self.draw_terminal("You died - Enter to restart level");
    }
}

impl Renderer.screenshot(path: str) {
    TakeScreenshot(path);
}

impl Renderer.close() {
    CloseWindow();
}


impl RenderPass.start with World entry {
    visit self.targets;
}

impl RenderPass.draw with Area entry {
    self.renderer.draw_area(here);
    self.drawn += 1;
}

impl Renderer.set_frame_limit(fps: int) {
    self.frame_limit = fps;
    SetTargetFPS(i32(fps));
}

impl Renderer.draw_opponents(world: World, height: float) {
    for enemy in [world->:HasOpponent:->][?:Opponent] {
        if enemy.health <= 0 or enemy.modeled {
            continue;
        }
        center = enemy.pos.sub(Vec3(z=height - 4.0));
        DrawCube(
            Vector3(x=f32(center.x), y=f32(center.y), z=f32(center.z)),
            f32(28.0),
            f32(28.0),
            f32(48.0),
            Color(r=180, g=40, b=35, a=255)
        );
        DrawCubeWires(
            Vector3(x=f32(center.x), y=f32(center.y), z=f32(center.z)),
            f32(30.0),
            f32(30.0),
            f32(50.0),
            Color(r=255, g=210, b=80, a=255)
        );
    }
}

impl Renderer.draw_combat(state: CombatState, arena: bool, ammo: int = -1) {
    rule = selected_weapon(state);
    color = Color(r=255, g=230, b=180, a=255);
    DrawText("+", i32(self.width / 2 - 6), i32(self.height / 2 - 12), 24, color);
    if state.hit_flash > 0.0 {
        DrawText(
            "X",
            i32(self.width / 2 - 8),
            i32(self.height / 2 - 12),
            24,
            Color(r=255, g=50, b=40, a=255)
        );
    }
    if state.flash > 0.0 {
        DrawText("*", i32(self.width / 2 - 12), i32(self.height - 120), 48, color);
    }
    DrawText(
        ("FRAGS " if arena else "KILLS ")
            + str(state.kills)
            + "    "
            + (
                "["
                + str(state.weapon % 10)
                + "] "
                + rule.name
                + " / "
                + (str(ammo) + " " + rule.ammo if ammo >= 0 else "unlimited")
            )
            + "    LMB: fire",
        20,
        i32(self.height - 68),
        20,
        color
    );
    if arena and state.kills >= 10 {
        self.draw_terminal("Arena won! Enter: rematch | Esc: choose level");
    }
}

impl Renderer.draw_message(message: str) {
    DrawText(
        message, 20, i32(self.height - 104), 20, Color(r=255, g=230, b=180, a=255)
    );
}


impl Renderer.draw_terminal(message: str) {
    y = self.height / 2 + 32;
    DrawRectangle(0, i32(y), i32(self.width), 56, Color(r=0, g=0, b=0, a=210));
    DrawText(message, 20, i32(y + 16), 24, Color(r=255, g=230, b=180, a=255));
}


impl Renderer.draw_keys(message: str) {
    if message {
        DrawText(
            message, 20, i32(self.height - 154), 20, Color(r=255, g=230, b=180, a=255)
        );
    }
}

impl Renderer.draw_loading(name: str) {
    if not IsWindowReady() {
        return;
    }
    BeginDrawing();
    ClearBackground(Color(r=10, g=8, b=6, a=255));
    DrawText(
        "Preparing expedition " + name,
        40,
        i32(self.height / 2 - 40),
        28,
        Color(r=255, g=230, b=180, a=255)
    );
    DrawText(
        "First visits take longer while lighting is prepared.",
        40,
        i32(self.height / 2 + 12),
        20,
        Color(r=190, g=180, b=160, a=255)
    );
    EndDrawing();
}


impl Renderer.draw_projectiles(world: World) {
    for projectile in [world->:HasProjectile:->][?:Projectile] {
        DrawCube(
            Vector3(
                x=f32(projectile.pos.x),
                y=f32(projectile.pos.y),
                z=f32(projectile.pos.z)
            ),
            f32(4.0),
            f32(4.0),
            f32(4.0),
            Color(r=255, g=150, b=40, a=255)
        );
    }
}
