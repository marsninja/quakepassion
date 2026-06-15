"""Implementations for the render module: the Renderer wall methods and the
RenderPass walker abilities. Declarations (and the raylib import) live in
renderer.na.jac."""

impl Renderer.open_window() {
    InitWindow(self.width, self.height, self.title);
    # fps intentionally uncapped: no SetTargetFPS, so raylib skips the
    # frame-end wait and renders as fast as the loop runs. The fixed-timestep
    # Clock keeps simulation rate independent of however fast frames fly.
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
        position=Vector3(x=eye.x, y=eye.y, z=eye.z),
        target=Vector3(x=target.x, y=target.y, z=target.z),
        up=Vector3(x=0.0, y=0.0, z=1.0),
        fovy=FOV_DEGREES,
        projection=CAMERA_PERSPECTIVE
    );
    BeginMode3D(cam);
}

impl Renderer.draw_area(area: Area) {
    for s in area.surfaces {
        pos = Vector3(x=s.center.x, y=s.center.y, z=s.center.z);
        face = Color(r=s.color[0], g=s.color[1], b=s.color[2], a=255);
        edge_c = Color(
            r=int(s.color[0] * 0.55),
            g=int(s.color[1] * 0.55),
            b=int(s.color[2] * 0.55),
            a=255
        );
        DrawCube(pos, s.size.x, s.size.y, s.size.z, face);
        DrawCubeWires(pos, s.size.x, s.size.y, s.size.z, edge_c);
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
        DrawText(line, 12, y, 20, amber);
        y += 26;
    }
}

impl Renderer.end_frame() {
    EndDrawing();
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
