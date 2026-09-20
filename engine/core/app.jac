"""The game loop: input → fixed-timestep ticks → render. Each tick spawns
the pass walkers over the world graph; each frame floods visibility and
draws only what the flood found.

Method bodies live in impl/app.impl.jac."""

import from ..world.level { Level, load_level, spawn_player }
import from .menu { LevelMenu, game_directory }
import from ..render.quake { QuakeRenderer }
import from .clock { Clock }
import from ..physics.movement { MovePlayer }
import from ..input.input {
    Intent,
    sample_intent,
    mouse_captured,
    IsKeyPressed,
    _capture,
    _release
}
import from ..math.vec3 { Vec3, forward_from, right_from }
import from ..render.renderer { Renderer, RenderPass }
import from ..world.world {
    World,
    Area,
    Player,
    ThinkPass,
    VisPass,
    area_containing,
    area_of,
    move_to_area
}


glob FLY_SPEED: float = 240.0;
glob PITCH_LIMIT: float = 1.45;


obj App {
    has world: World,
        player: Player,
        renderer: Renderer,
        clock: Clock,
        culling: bool = True,
        overlay: bool = True,
        smoke: bool = False,
        last_think: int = 0,
        last_drawn: int = 0,
        level: Level = Level(),
        quake: QuakeRenderer = QuakeRenderer(),
        menu: LevelMenu = LevelMenu(),
        skip_time: bool = False,
        walking: bool = False,
        fly_speed: float = 240.0,
        sensitivity: float = 0.0022,
        invert_y: bool = False,
        jump_pending: bool = False,
        physics_clock: Clock = Clock(tick_rate=1.0 / 120.0, max_ticks_per_frame=30),
        movement_status: str = "F4: walk / fly";

    def adjust_setting(direction: int);
    def reset_settings();
    def refresh_settings();
    def run();
    def step() -> bool;
    def switch_level();
    def fly(intent: Intent, dt: float);
    def toggle_movement();
    def render_frame();
    """Headless validation script: steer the camera through three known
    states and screenshot each, then quit. Drives the exact culling
    behavior a human would check by hand."""
    def smoke_step(frame: int) -> bool;
}
