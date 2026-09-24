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
    # raylib keeps a pointer to the active batch, so it lives in a pin.
    batch = pin(rlLoadRenderBatch(i32(BATCH_BUFFERS), i32(BATCH_ELEMENTS)));
    self.batch = batch;
    rlSetRenderBatchActive(&mut batch);
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

impl Renderer.draw_status(health: int, armor: int, shells: int = 0, arena: bool = False) {
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
    if health <= 0 and not arena {
        self.draw_terminal("You died - Enter to restart level");
    }
}

impl Renderer.draw_aim(state: CombatState, crosshair: bool, score: str) {
    color = Color(r=255, g=230, b=180, a=255);
    if crosshair {
        DrawText("+", i32(self.width / 2 - 6), i32(self.height / 2 - 12), 24, color);
    }
    if state.hit_flash > 0.0 {
        DrawText("X", i32(self.width / 2 - 8), i32(self.height / 2 - 12), 24, Color(r=255, g=50, b=40, a=255));
    }
    if score {
        DrawText(score, i32(self.width - 20 - len(score) * 11), 16, 20, color);
    }
}

impl Renderer.screenshot(path: str) {
    TakeScreenshot(path);
}

impl Renderer.close() {
    batch = self.batch;
    if batch is not None {
        rlSetRenderBatchActive(None);
        rlUnloadRenderBatch(batch.value);
        self.batch = None;
    }
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

impl Renderer.draw_combat(state: CombatState, arena: bool, ammo: int = -1, score: str = "") {
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
        (score if score else ("FRAGS " if arena else "KILLS ") + str(state.kills))
            + "    "
            + (
                "["
                + ("G" if rule.hand_thrown else str(state.weapon % 10))
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
}

impl Renderer.draw_scoreboard(title: str, lines: list[str], footer: str) {
    height = float(110 + len(lines) * 30);
    top = max(20.0, float(self.height) / 2.0 - height / 2.0 - 60.0);
    left = max(20.0, float(self.width) / 2.0 - 320.0);
    DrawRectangle(i32(left), i32(top), 640, i32(height), Color(r=0, g=0, b=0, a=190));
    gold = Color(r=255, g=210, b=120, a=255);
    DrawText(title, i32(left + 24), i32(top + 18), 26, gold);
    y = top + 60;
    for line in lines {
        DrawText(
            line,
            i32(left + 24),
            i32(y),
            22,
            gold if "(you)" in line else Color(r=235, g=225, b=205, a=255)
        );
        y += 30;
    }
    if footer {
        DrawText(footer, i32(left + 24), i32(y + 12), 20, Color(r=190, g=180, b=160, a=255));
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


impl Renderer.draw_finale(text: str, prompt: str) {
    DrawRectangle(0, 0, i32(self.width), i32(self.height), Color(r=0, g=0, b=0, a=200));
    lines = text.split("\n");
    y = self.height / 2 - len(lines) * 14 - 20;
    for line in lines {
        DrawText(line, 80, i32(y), 22, Color(r=255, g=230, b=180, a=255));
        y += 28;
    }
    DrawText(prompt, 80, i32(self.height - 70), 22, Color(r=190, g=180, b=160, a=255));
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


impl Renderer.draw_projectiles(world: World, hidden_effects: list[str] = []) {
    for trail in [world->:HasTrail:->][?:ShotTrail] {
        alpha = int(255.0 * min(1.0, trail.remaining / 0.2));
        color = Color(r=100, g=160, b=255, a=u8(alpha));
        if trail.kind == "lightning" {
            color = Color(r=220, g=235, b=255, a=u8(alpha));
        } elif trail.kind == "drain" {
            color = Color(r=120, g=255, b=120, a=u8(alpha));
        } elif trail.kind.startswith("laser_") {
            # Q2 target_laser palette colours.
            shade = {
                "laser_red": [255, 40, 30],
                "laser_green": [60, 255, 60],
                "laser_blue": [70, 110, 255],
                "laser_yellow": [255, 230, 60],
                "laser_orange": [255, 150, 40]
            }.get(trail.kind, [255, 40, 30]);
            color = Color(r=u8(shade[0]), g=u8(shade[1]), b=u8(shade[2]), a=u8(255));
        }
        DrawLine3D(
            Vector3(x=f32(trail.start.x), y=f32(trail.start.y), z=f32(trail.start.z)),
            Vector3(
                x=f32(trail.finish.x), y=f32(trail.finish.y), z=f32(trail.finish.z)
            ),
            color
        );
        if trail.kind == "lightning" {
            DrawLine3D(
                Vector3(
                    x=f32(trail.start.x), y=f32(trail.start.y), z=f32(trail.start.z + 2.0)
                ),
                Vector3(
                    x=f32(trail.finish.x),
                    y=f32(trail.finish.y),
                    z=f32(trail.finish.z + 2.0)
                ),
                Color(r=140, g=170, b=255, a=u8(alpha))
            );
        }
    }
    for particle in [world->:HasParticle:->][?:ImpactParticle] {
        fade = max(0.0, particle.remaining / particle.lifetime);
        color = Color(r=170, g=20, b=15, a=u8(int(255.0 * fade)))
            if particle.blood
            else Color(r=210, g=185, b=145, a=u8(int(255.0 * fade)));
        size = f32(0.4 + fade * 0.6);
        DrawCube(
            Vector3(
                x=f32(particle.pos.x), y=f32(particle.pos.y), z=f32(particle.pos.z)
            ),
            size,
            size,
            size,
            color
        );
    }
    for event in [world->:HasLightning:->][?:LightningEvent] {
        doors = [event->:Electrode:->][?:Door];
        if event.remaining > 0.0 and len(doors) == 2 {
            start = electrode_point(doors[0]);
            finish = electrode_point(doors[1]);
            DrawLine3D(
                Vector3(x=f32(start.x), y=f32(start.y), z=f32(start.z)),
                Vector3(x=f32(finish.x), y=f32(finish.y), z=f32(finish.z)),
                Color(r=150, g=190, b=255, a=255)
            );
        }
    }
    for projectile in [world->:HasProjectile:->][?:Projectile] {
        origin = Vector3(
            x=f32(projectile.pos.x), y=f32(projectile.pos.y), z=f32(projectile.pos.z)
        );
        color = Color(r=70, g=255, b=70, a=255)
            if projectile.beam_damage > 0
            else Color(r=255, g=150, b=40, a=255);
        size = f32(
            4.0 if projectile.phase == 0 else 12.0 + (0.5 - projectile.remaining) * 60.0
        );
        if projectile.effect not in hidden_effects {
            DrawCube(origin, size, size, size, color);
        }
        for finish in projectile.beams {
            DrawLine3D(
                origin,
                Vector3(x=f32(finish.x), y=f32(finish.y), z=f32(finish.z)),
                color
            );
        }
    }
}

impl Renderer.draw_tint(r: int, g: int, b: int, a: int) {
    DrawRectangle(
        0,
        0,
        i32(self.width),
        i32(self.height),
        Color(r=u8(r), g=u8(g), b=u8(b), a=u8(a))
    );
}

impl Renderer.draw_powerups(lines: list[str]) {
    y = self.height - 140 - len(lines) * 24;
    for line in lines {
        DrawText(line, i32(self.width - 360), i32(y), 20, Color(r=140, g=200, b=255, a=255));
        y += 24;
    }
}
