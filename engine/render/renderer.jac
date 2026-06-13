"""The raylib wall. Every rendering call in the engine lives here — swapping
the graphics backend later touches this file and nothing else."""

import pyray as rl;

import from ..math.vec3 { Vec3, forward_from }
import from ..world.world { World, Area }


glob FOV_DEGREES: float = 72.0;


obj Renderer {
    has width: int = 1280,
        height: int = 720,
        title: str = "QuakePassion — Phase 1: First Light";

    def open_window() {
        rl.init_window(self.width, self.height, self.title);
        rl.set_target_fps(120);
    }

    def should_close() -> bool {
        return rl.window_should_close();
    }

    def frame_time() -> float {
        return rl.get_frame_time();
    }

    def begin_frame(eye: Vec3, yaw: float, pitch: float) {
        rl.begin_drawing();
        rl.clear_background(rl.Color(10, 8, 6, 255));
        target = eye.add(forward_from(yaw, pitch));
        cam = rl.Camera3D(
            rl.Vector3(eye.x, eye.y, eye.z),
            rl.Vector3(target.x, target.y, target.z),
            rl.Vector3(0.0, 0.0, 1.0),
            FOV_DEGREES,
            rl.CAMERA_PERSPECTIVE
        );
        rl.begin_mode_3d(cam);
    }

    def draw_area(area: Area) {
        for s in area.surfaces {
            c = rl.Color(s.color[0], s.color[1], s.color[2], 255);
            edge_c = rl.Color(
                int(s.color[0] * 0.55),
                int(s.color[1] * 0.55),
                int(s.color[2] * 0.55),
                255
            );
            pos = rl.Vector3(s.center.x, s.center.y, s.center.z);
            rl.draw_cube(pos, s.size.x, s.size.y, s.size.z, c);
            rl.draw_cube_wires(pos, s.size.x, s.size.y, s.size.z, edge_c);
        }
    }

    def end_scene() {
        rl.end_mode_3d();
    }

    def draw_overlay(lines: list[str]) {
        rl.draw_fps(12, 12);
        y = 40;
        for line in lines {
            rl.draw_text(line, 12, y, 20, rl.Color(255, 184, 107, 255));
            y += 26;
        }
    }

    def end_frame() {
        rl.end_drawing();
    }

    def screenshot(path: str) {
        rl.take_screenshot(path);
    }

    def close() {
        rl.close_window();
    }
}


"""Draw dispatch as traversal: visit exactly the areas VisPass collected and
hand each to the renderer. The walker only dispatches — every raylib call
stays behind the Renderer wall. It lives here in the render layer (not in
engine/world) so `renderer` can be concretely typed without a world->renderer
import cycle."""
walker RenderPass {
    has renderer: Renderer,
        targets: list[Area] = [],
        drawn: int = 0;

    can start with World entry {
        visit self.targets;
    }

    can draw with Area entry {
        self.renderer.draw_area(here);
        self.drawn += 1;
    }
}
