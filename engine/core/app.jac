"""The game loop: input → fixed-timestep ticks → render. Each tick spawns
the pass walkers over the world graph; each frame floods visibility and
draws only what the flood found.

Method bodies live in impl/app.impl.jac."""
import math;
import from ..world.doors { BlastMover }
import from ..world.gates { ApplyGates, rune_summary }
import from ..world.chthon { ChthonTick }
import from ..world.finale {
    FinaleTick,
    Finale,
    HasFinale,
    intermission_camera,
    episode_text,
    RUNES_TEXT,
    VICTORY_TEXT
}
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
import from ..world.rotators { RotatorTick }
import from ..world.shooters { ShooterTick }
import from ..world.targets { TargetTick, HasHelp, HelpComputer }
import from ..world.triggers { TriggerTick, ShootTrigger, MonsterJumpTick }
import from ..world.traversal { TraversalTick }
import from ..world.arena_navigation {
    ArenaNavigationTick,
    ArenaContactIndex,
    prepare_arena_links
}
import from ..world.exits { ExitTick, exit_map, exit_spawn, exit_cinematic }
import from ..world.environment { EnvironmentTick }
import from ..world.pickups { PickupTick }
import from ..world.arena {
    ArenaMatch,
    Competes,
    MatchTick,
    ChooseSpawn,
    SpawnPoint,
    HasSpawn,
    match_of,
    join_match,
    standings,
    credit_impressive,
    ordinal
}
import from games.arenas { ArenaProgress, load_arenas, next_arena }
import from ..world.powerups {
    PowerupTick,
    UseItem,
    Powerup,
    Empowered,
    empowered,
    powerup_left,
    powerup_rule,
    owned_items,
    item_label,
    effect
}
import from ..world.inventory {
    Inventory,
    quantity,
    CopyInventory,
    key_summary,
    AdjustInventory
}
import from ..assets.library { AssetLibrary }
import from ..world.combat {
    CombatState,
    CombatTick,
    Opponent,
    HasOpponent,
    ProjectileTick,
    fire_weapon,
    weapon_input,
    select_weapon,
    selected_weapon,
    owns_weapon,
    KillBox
}
import from ..world.light_effects { combat_lights }
import from games.opponents { populate_opponents, populate_finale }
import from games.items { populate_pickups }
import from games.fixtures { populate_fixtures }
import from ..world.fixtures { FixtureTick }
import from ..world.gibs { GibTick }
import from ..world.patrols { PatrolTick }
import from ..world.bot_tactics { BotTactics }
import from ..world.lightstyles { LightStyles, HasLightStyles, LightStyleTick }
import from ..world.clocks { ClockTick, HasClock }
import from ..world.flyers { FlyerTick, HasFlyer, HasBomb }
import from ..world.turrets { TurretTick, HasTurret }
import from ..world.podium { PodiumTick, arena_intermission, raise_podium }
import from ..render.portal { PortalTarget, draw_portal_view }
import from ..render.hud_models { HudModels }
import from ..world.reflection { show_body, follow_body }
import from ..world.drops { toss_items }
import from ..world.falling { FallingTick, HasFallingObject }
import from ..world.trail { TrailTick, PlayerTrail, trail_of }
import from ..render.hud { HudRenderer, HudStatus }
import from games.hud_art { load_hud_art, load_q3_models }
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
        scripted: Intent | None = None,
        last_think: int = 0,
        last_drawn: int = 0,
        level: Level = Level(),
        quake: QuakeRenderer = QuakeRenderer(),
        portal_target: PortalTarget = PortalTarget(),
        hud_models: HudModels = HudModels(),
        level_clocks: bool = False,
        level_falling: bool = False,
        level_flyers: bool = False,
        level_turrets: bool = False,
        player_trail: PlayerTrail | None = None,
        models: ModelScene = ModelScene(),
        effects: EffectScene = EffectScene(),
        viewweapon: ViewWeapon = ViewWeapon(),
        hud: HudRenderer = HudRenderer(),
        light_styles: LightStyles | None = None,
        style_serial: int = -1,
        pain_time: float = 0.0,
        pain_health: int = 0,
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
        arena_contacts: ArenaContactIndex = ArenaContactIndex(),
        physics_clock: Clock = Clock(tick_rate=1.0 / 120.0, max_ticks_per_frame=30),
        movement_status: str = "F4: walk / fly",
        save_path: str = "",
        notice: str = "",
        notice_wait: float = 0.0,
        selected_item: int = 0,
        frame_dt: float = 0.0,
        skill: int = 1,
        quad_sound_wait: float = 0.0,
        respawn_wait: float = 0.0,
        awaiting_respawn: bool = False,
        show_scores: bool = False,
        arena_progress: ArenaProgress = ArenaProgress();

    has expedition_complete: bool = False;
    has finale_text: str = "",
        finale_active: bool = False,
        intermission_text: str = "",
        pending_map: str = "",
        pending_spawn: str = "",
        pending_unit: bool = False,
        campaign_complete: bool = False,
        runes_message: bool = False;

    def begin_intermission(text: str);
    def begin_podium(contest: ArenaMatch);
    def render_portal(faces: list[int]);
    def survey_level();
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
    def use_item(kind: str = "");
    def teleport_actor(actor: Player);
    def tick_powerups(dt: float);
    def show_notice(message: str);
    def draw_powerup_blend();
    def respawn_arena_player();
    def arena_lines(contest: ArenaMatch) -> list[str];
    def finish_arena(contest: ArenaMatch);
    def powerup_lines() -> list[str];
    """Load the original status bar art and the light styles for the level."""
    def prepare_presentation();
    """What the original status bar shows this frame."""
    def hud_status() -> HudStatus;
    def render_frame();
    """Headless validation script: steer the camera through three known
    states and screenshot each, then quit. Drives the exact culling
    behavior a human would check by hand."""
    def smoke_step(frame: int) -> bool;
}
