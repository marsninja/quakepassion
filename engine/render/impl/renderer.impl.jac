"""Implementations for the render module: the Renderer wall methods and the
RenderPass walker abilities. Declarations (and the raylib import) live in
renderer.jac."""

impl Renderer.declare(shell: Shell) {
    cvars = self.cvars;
    cvars.fov = shell.register(cvars.fov);
    cvars.maxfps = shell.register(cvars.maxfps);
    cvars.novis = shell.register(cvars.novis);
    cvars.width = shell.register(cvars.width);
    cvars.height = shell.register(cvars.height);
    cvars.fullscreen = shell.register(cvars.fullscreen);
    cvars.highdpi = shell.register(cvars.highdpi);
    cvars.subdivisions = shell.register(cvars.subdivisions);
    cvars.lod_curve_error = shell.register(cvars.lod_curve_error);
}

impl Renderer.open_window() {
    # A resizable window; with vid_highdpi the framebuffers are the display's
    # pixels while 2D drawing stays in screen units.
    flags = WINDOW_RESIZABLE_FLAG;
    if self.cvars.highdpi.on() {
        flags = flags | WINDOW_HIGHDPI_FLAG;
    }
    if os.getenv("QP_HEADLESS", "") not in ["", "0"] {
        # Run without showing a window: scripts drive it and read what it prints and captures.
        flags = flags | WINDOW_HIDDEN_FLAG;
    }
    SetConfigFlags(u32(flags));
    InitWindow(i32(self.cvars.width.integer), i32(self.cvars.height.integer), self.title);
    if not IsWindowReady() {
        raise RuntimeError(
            "Cannot open the viewer window: an active graphical desktop/display is required."
        );
    }
    SetWindowMinSize(i32(320), i32(240));
    SetExitKey(i32(0));  # Escape belongs to the level menu.
    # raylib keeps a pointer to the active batch, so it lives in a pin. Each
    # buffer's vertex array enables only the attributes of the shader current
    # while it loads; rlglInit pretends the default shader has vertexNormal for
    # its own batch. Load ours under a shader with all four, or the normals
    # that carry Q3 lightmap coordinates never reach any shader.
    attributes = LoadShaderFromMemory(BATCH_ATTRIBUTES_VS, BATCH_ATTRIBUTES_FS);
    BeginShaderMode(attributes);
    batch = pin(rlLoadRenderBatch(i32(BATCH_BUFFERS), i32(BATCH_ELEMENTS)));
    EndShaderMode();
    UnloadShader(attributes);
    self.batch = batch;
    rlSetRenderBatchActive(&mut batch);
    # Default to uncapped rendering; a user-selected limit only paces frames.
    # Simulation keeps its independent fixed timestep.
    self.cvars.maxfps.modified = True;
    if self.cvars.fullscreen.on() {
        self.apply_video();
    }
    self.sync();
}

impl Renderer.sync() {
    cvars = self.cvars;
    # A window the player resizes keeps its size; a fullscreen one covers the
    # monitor and leaves the windowed size alone.
    if IsWindowResized() and not cvars.fullscreen.on() {
        cvars.width.assign(str(int(GetScreenWidth())));
        cvars.height.assign(str(int(GetScreenHeight())));
    }
    self.width = max(1, int(GetScreenWidth()));
    self.height = max(1, int(GetScreenHeight()));
    # SCR_CalcRefdef: fov is the horizontal angle of a 4:3 view; the vertical
    # angle stays and wider windows see more to the sides.
    self.fov = math.degrees(
        2.0 * math.atan(math.tan(math.radians(cvars.fov.number) * 0.5) * 0.75)
    );
    if cvars.maxfps.modified {
        cvars.maxfps.modified = False;
        SetTargetFPS(i32(cvars.maxfps.integer));
    }
}

impl Renderer.apply_video() {
    cvars = self.cvars;
    # Fullscreen is a window without decorations covering its monitor at the
    # desktop resolution. Putting the window on the monitor itself (exclusive
    # or GLFW "borderless" fullscreen) makes macOS switch the display to the
    # nearest video mode, which loses the desktop resolution and HiDPI.
    monitor = GetCurrentMonitor();
    corner = GetMonitorPosition(monitor);
    if cvars.fullscreen.on() {
        SetWindowState(u32(WINDOW_UNDECORATED_FLAG));
        SetWindowPosition(i32(int(corner.x)), i32(int(corner.y)));
        SetWindowSize(GetMonitorWidth(monitor), GetMonitorHeight(monitor));
    } else {
        ClearWindowState(u32(WINDOW_UNDECORATED_FLAG));
        SetWindowSize(i32(cvars.width.integer), i32(cvars.height.integer));
        SetWindowPosition(
            i32(int(corner.x) + max(0, (int(GetMonitorWidth(monitor)) - cvars.width.integer) // 2)),
            i32(int(corner.y) + max(0, (int(GetMonitorHeight(monitor)) - cvars.height.integer) // 2))
        );
    }
    self.width = max(1, int(GetScreenWidth()));
    self.height = max(1, int(GetScreenHeight()));
}

impl Renderer.should_close() -> bool {
    return WindowShouldClose();
}

impl Renderer.frame_time() -> float {
    return GetFrameTime();
}

impl Renderer.begin_frame(eye: Vec3, yaw: float, pitch: float, roll: float = 0.0) {
    BeginDrawing();
    ClearBackground(Color(r=10, g=8, b=6, a=255));
    ahead = forward_from(yaw, pitch);
    target = eye.add(ahead);
    # A rolled view tilts the camera's up vector about the line of sight.
    up = Vec3(z=1.0);
    if abs(roll) > 0.000001 {
        side = right_from(yaw);
        level = side.cross(ahead).normalized();
        up = level.scale(math.cos(roll)).add(side.scale(math.sin(roll)));
    }
    cam = Camera3D(
        position=Vector3(x=f32(eye.x), y=f32(eye.y), z=f32(eye.z)),
        target=Vector3(x=f32(target.x), y=f32(target.y), z=f32(target.z)),
        up=Vector3(x=f32(up.x), y=f32(up.y), z=f32(up.z)),
        fovy=f32(self.fov),
        projection=i32(CAMERA_PERSPECTIVE)
    );
    rlSetClipPlanes(f64(1.0), f64(32768.0));
    BeginMode3D(cam);
}

impl Renderer.begin_screen() {
    BeginDrawing();
    ClearBackground(Color(r=0, g=0, b=0, a=255));
}

impl Renderer.begin_views() {
    BeginDrawing();
    ClearBackground(Color(r=21, g=20, b=18, a=255));
}

impl Renderer.begin_view(
    x: int, y: int, width: int, height: int, eye: Vec3, yaw: float, pitch: float, span: float = 0.0
) {
    ahead = forward_from(yaw, pitch);
    target = eye.add(ahead);
    # Looking straight up or down, "up" on screen is the way the yaw faces.
    up = Vec3(z=1.0);
    if abs(ahead.z) > 0.999 {
        up = Vec3(x=math.cos(yaw), y=math.sin(yaw));
        if ahead.z > 0.0 {
            up = up.scale(-1.0);
        }
    }
    cam = Camera3D(
        position=Vector3(x=f32(eye.x), y=f32(eye.y), z=f32(eye.z)),
        target=Vector3(x=f32(target.x), y=f32(target.y), z=f32(target.z)),
        up=Vector3(x=f32(up.x), y=f32(up.y), z=f32(up.z)),
        fovy=f32(self.fov),
        projection=i32(CAMERA_PERSPECTIVE)
    );
    near = 1.0;
    far = 32768.0;
    rlSetClipPlanes(f64(near), f64(far));
    BeginMode3D(cam);
    # The rectangle in framebuffer pixels, counted from the bottom.
    scale = float(GetRenderWidth()) / float(max(1, self.width));
    rlViewport(
        i32(int(float(x) * scale)),
        i32(int(float(self.height - y - height) * scale)),
        i32(max(1, int(float(width) * scale))),
        i32(max(1, int(float(height) * scale)))
    );
    aspect = float(max(1, width)) / float(max(1, height));
    # Kept, for a band of depth set over the view.
    self.view_span = span;
    self.view_width = width;
    self.view_height = height;
    projection = Matrix(
        m0=f32(0.0), m4=f32(0.0), m8=f32(0.0), m12=f32(0.0),
        m1=f32(0.0), m5=f32(0.0), m9=f32(0.0), m13=f32(0.0),
        m2=f32(0.0), m6=f32(0.0), m10=f32(0.0), m14=f32(0.0),
        m3=f32(0.0), m7=f32(0.0), m11=f32(0.0), m15=f32(0.0)
    );
    if span > 0.0 {
        # Orthographic views see both ways along their axis.
        near = -far;
        projection.m0 = f32(2.0 / (span * aspect));
        projection.m5 = f32(2.0 / span);
        projection.m10 = f32(-2.0 / (far - near));
        projection.m14 = f32(-(far + near) / (far - near));
        projection.m15 = f32(1.0);
    } else {
        f = 1.0 / math.tan(math.radians(self.fov) * 0.5);
        projection.m0 = f32(f / aspect);
        projection.m5 = f32(f);
        projection.m10 = f32(-(far + near) / (far - near));
        projection.m14 = f32(-2.0 * far * near / (far - near));
        projection.m11 = f32(-1.0);
    }
    rlSetMatrixProjection(projection);
}

impl Renderer.view_depth(near: float, far: float) {
    if self.view_span <= 0.0 {
        return;
    }
    rlDrawRenderBatchActive();
    deep = 32768.0;
    low = near if far > near else -deep;
    high = far if far > near else deep;
    aspect = float(max(1, self.view_width)) / float(max(1, self.view_height));
    projection = Matrix(
        m0=f32(2.0 / (self.view_span * aspect)), m4=f32(0.0), m8=f32(0.0), m12=f32(0.0),
        m1=f32(0.0), m5=f32(2.0 / self.view_span), m9=f32(0.0), m13=f32(0.0),
        m2=f32(0.0), m6=f32(0.0), m10=f32(-2.0 / (high - low)), m14=f32(-(high + low) / (high - low)),
        m3=f32(0.0), m7=f32(0.0), m11=f32(0.0), m15=f32(1.0)
    );
    rlSetMatrixProjection(projection);
}

impl Renderer.end_view() {
    EndMode3D();
    rlDrawRenderBatchActive();
    rlViewport(i32(0), i32(0), GetRenderWidth(), GetRenderHeight());
}

impl Renderer.clear_rect(x: int, y: int, width: int, height: int) {
    if width <= 0 or height <= 0 {
        return;
    }
    BeginScissorMode(i32(x), i32(y), i32(width), i32(height));
    ClearBackground(Color(r=21, g=20, b=18, a=255));
    EndScissorMode();
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
    # raylib's TakeScreenshot scales the framebuffer size by the display's
    # DPI again under FLAG_WINDOW_HIGHDPI, reading past the frame; read the
    # framebuffer's own size instead.
    width = GetRenderWidth();
    height = GetRenderHeight();
    pixels = rlReadScreenPixels(width, height);
    if pixels == u64(0) {
        return;
    }
    ExportImage(ScreenImage(data=pixels, width=width, height=height, mipmaps=i32(1), format=i32(7)), path);
    MemFree(pixels);
}

impl Renderer.close() {
    self.cubes.close();
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
    self.cvars.maxfps.assign(str(fps));
    self.cvars.maxfps.modified = False;
    SetTargetFPS(i32(self.cvars.maxfps.integer));
}

impl Renderer.draw_opponents(world: World, height: float, blend: TickBlend = TickBlend()) {
    for enemy in [world->:HasOpponent:->][?:Opponent] {
        if enemy.health <= 0 or enemy.modeled {
            continue;
        }
        center = blend.place(enemy.tick_pose, enemy.pos).sub(Vec3(z=height - 4.0));
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
                + ("G" if rule.hand_thrown else (str(rule.role) if rule.role > 0 else str(state.weapon % 10)))
                + "] "
                + rule.name
                # A Passion player's gun says whose it is.
                + (" (" + {"q1": "Quake", "q2": "Quake II", "q3": "Quake III"}.get(rule.game, rule.game) + ")" if rule.role > 0 else "")
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
    # Mission prerequisites and notices must remain visible when the
    # player resizes the window. Wrap above the status rows.
    lines: list[str] = [];
    for paragraph in message.split("\n") {
        line = "";
        for word in paragraph.split() {
            candidate = line + (" " if line else "") + word;
            if line and int(MeasureText(candidate, 20)) > self.width - 40 {
                lines.append(line);
                line = word;
            } else { line = candidate; }
        }
        if line { lines.append(line); }
    }
    top = max(8, self.height - 104 - max(0, len(lines) - 1) * 24);
    for (index, line) in enumerate(lines) {
        DrawText(line, 20, i32(top + index * 24), 20, Color(r=255, g=230, b=180, a=255));
    }
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

impl Renderer.draw_loading(name: str, stage: str = "", share: float = -1.0) {
    if not IsWindowReady() {
        return;
    }
    BeginDrawing();
    ClearBackground(Color(r=10, g=8, b=6, a=255));
    DrawText(
        "Making " + name,
        40,
        i32(self.height / 2 - 40),
        28,
        Color(r=255, g=230, b=180, a=255)
    );
    words = {
        "survey": "Laying out rooms and the ways between them",
        "map": "Writing the brushes",
        "compile": "Building the level",
        "bake": "Lighting it",
        "ready": "Opening it"
    };
    DrawText(
        words.get(stage, "Rolling the dice"),
        40,
        i32(self.height / 2 + 12),
        20,
        Color(r=190, g=180, b=160, a=255)
    );
    if share >= 0.0 {
        wide = max(100, self.width - 80);
        DrawRectangle(40, i32(self.height / 2 + 48), i32(wide), 10, Color(r=48, g=40, b=32, a=255));
        DrawRectangle(40, i32(self.height / 2 + 48), i32(int(float(wide) * max(0.0, min(1.0, share)))), 10, Color(r=255, g=184, b=107, a=255));
    }
    EndDrawing();
}


impl Renderer.draw_projectiles(
    world: World, hidden_effects: list[str] = [], blend: TickBlend = TickBlend()
) {
    for trail in [world->:HasTrail:->][?:ShotTrail] {
        # Styled rails and beams are drawn by the effect scene.
        if trail.kind in hidden_effects {
            continue;
        }
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
    # Impact and explosion particles are drawn by the effect scene; plain
    # projectile markers go to the instanced cube batch.
    cubes = self.cubes;
    immediate = cubes.immediate();
    for projectile in [world->:HasProjectile:->][?:Projectile] {
        at = blend.place(projectile.tick_pose, projectile.pos);
        origin = Vector3(x=f32(at.x), y=f32(at.y), z=f32(at.z));
        color = Color(r=70, g=255, b=70, a=255)
            if projectile.beam_damage > 0
            else Color(r=255, g=150, b=40, a=255);
        side = f32(
            4.0 if projectile.phase == 0 else 12.0 + (0.5 - projectile.remaining) * 60.0
        );
        if projectile.effect not in hidden_effects {
            if immediate {
                DrawCube(origin, side, side, side, color);
            } else {
                cubes.add(at.x, at.y, at.z, float(side), int(color.r), int(color.g), int(color.b), int(color.a));
            }
        }
        for finish in (projectile.beams if projectile.effect not in hidden_effects else []) {
            DrawLine3D(
                origin,
                Vector3(x=f32(finish.x), y=f32(finish.y), z=f32(finish.z)),
                color
            );
        }
    }
    cubes.draw();
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

impl Renderer.wire(on: bool) {
    rlDrawRenderBatchActive();
    if on {
        rlEnableWireMode();
    } else {
        rlDisableWireMode();
    }
}
