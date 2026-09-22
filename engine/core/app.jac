"""The game loop: input → fixed-timestep ticks → render. Each tick spawns
the pass walkers over the world graph; each frame floods visibility and
draws only what the flood found.

Method bodies live in impl/app.impl.jac."""
import from ..world.doors { BlastMover }
import from ..world.gates { ApplyGates, rune_summary }
import from ..world.chthon { ChthonTick }
import from ..world.trains { TrainTick, ShootMover }
import from ..world.signals { SignalTick, progress_summary }
import from ..world.hazards { HazardTick }
import from ..world.speakers { SpeakerTick }
import from ..world.brushes { BrushTick, ShootBrush, BlastBrush }

import os;
import from games.weapons { equip_player, weapon_sounds, weapon_effects }
import from .campaign { Campaign, Remember, Recall, pack_campaign, unpack_campaign }
import from .preferences { Preferences }
import from ..audio.feedback { Feedback }
import from .savegame { snapshot, restore, write_save, read_save }
import from ..world.doors { DoorTick }
import from ..world.triggers { TriggerTick }
import from ..world.traversal { TraversalTick }
import from ..world.exits { ExitTick, exit_map, exit_spawn }
import from ..world.environment { EnvironmentTick }
import from ..world.pickups { PickupTick }
import from ..world.inventory { quantity, CopyInventory, key_summary, AdjustInventory }
import from ..world.combat {
    CombatState,
    CombatTick,
    ProjectileTick,
    fire_weapon,
    weapon_input,
    select_weapon,
    selected_weapon
}
import from ..world.light_effects { combat_lights }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.levels { open_level }
import from ..render.effects { EffectScene }
import from ..render.viewweapon { ViewWeapon }
import from games.viewweapons { view_weapons }
import from ..render.models { ModelScene }
import from ..world.level { Level, load_level, spawn_player }
import from .save_format { SNAPSHOT_HEADER }
import from .menu { LevelMenu, game_directory }
import from ..render.quake { QuakeRenderer }
import from .clock { Clock }
import from ..physics.movement { MovePlayer, SetStance }
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
        models: ModelScene = ModelScene(),
        effects: EffectScene = EffectScene(),
        viewweapon: ViewWeapon = ViewWeapon(),
        simulation_time: float = 0.0,
        combat: CombatState = CombatState(),
        campaign: Campaign = Campaign(),
        audio: Feedback = Feedback(),
        menu: LevelMenu = LevelMenu(),
        skip_time: bool = False,
        walking: bool = False,
        fly_speed: float = 240.0,
        sensitivity: float = 0.0022,
        invert_y: bool = False,
        god_mode: bool = False,
        jump_pending: bool = False,
        physics_clock: Clock = Clock(tick_rate=1.0 / 120.0, max_ticks_per_frame=30),
        movement_status: str = "F4: walk / fly",
        save_path: str = "",
        notice: str = "",
        notice_wait: float = 0.0;

    has expedition_complete: bool = False;

    def adjust_setting(direction: int);
    def reset_settings();
    def refresh_settings();
    def run();
    def step() -> bool;
    def switch_level();
    def load_destination(
        game: str,
        name: str,
        spawnpoint: str = "",
        carry: bool = False,
        saved: str = "",
        new_unit: bool = False,
        session: Campaign | None = None,
        preserve_progress: bool = False
    );

    def save_preferences();
    def quicksave();
    def quickload();
    def fly(intent: Intent, dt: float);
    def toggle_movement();
    def render_frame();
    """Headless validation script: steer the camera through three known
    states and screenshot each, then quit. Drives the exact culling
    behavior a human would check by hand."""
    def smoke_step(frame: int) -> bool;
}
