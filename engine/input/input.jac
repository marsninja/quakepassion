"""Input sampling. The only place that reads raylib input state; everything
downstream consumes an Intent."""

import pyray as rl;

import from ..math.vec3 { Vec3 }


obj Intent {
    has move: Vec3 = Vec3(),
        look_yaw: float = 0.0,
        look_pitch: float = 0.0,
        toggle_culling: bool = False,
        toggle_overlay: bool = False;
}


glob MOUSE_SENSITIVITY: float = 0.0022;


def sample_intent() -> Intent {
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

    md = rl.get_mouse_delta();
    return Intent(
        move=mv,
        look_yaw=-md.x * MOUSE_SENSITIVITY,
        look_pitch=-md.y * MOUSE_SENSITIVITY,
        toggle_culling=rl.is_key_pressed(rl.KEY_C),
        toggle_overlay=rl.is_key_pressed(rl.KEY_F3)
    );
}
