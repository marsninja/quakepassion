import math;
import from engine.world.world { World, Area, Player, move_to_area }
import from engine.world.powerups { GrantPowerup }
import from engine.world.models {
    ModelResource,
    GatherModels,
    PlayerRig,
    AnimationClip,
    LerpFrame,
    WeaponKit,
    KitPart,
    HasVisual
}
import from engine.world.player_rig {
    PoseRig,
    rig_clips,
    dress_rig,
    hold_kit,
    run_lerp_frame,
    swing_angle,
    movement_dir,
    rig_sound,
    ANIM_LEGS_IDLE,
    ANIM_LEGS_RUN,
    ANIM_LEGS_BACK,
    ANIM_LEGS_JUMP,
    ANIM_LEGS_LAND,
    ANIM_LEGS_TURN,
    ANIM_LEGS_BACKWALK,
    ANIM_TORSO_ATTACK,
    ANIM_TORSO_ATTACK2,
    ANIM_TORSO_STAND,
    ANIM_TORSO_STAND2,
    ANIM_TORSO_DROP,
    ANIM_TORSO_RAISE,
    ANIM_TORSO_GESTURE,
    ANIM_BOTH_DEATH1
}
import from engine.world.body_queue { Corpse, HasCorpse, CorpseTick, leave_corpse }
import from games.arena_character { animation_settings }
import from engine.formats.animated { AnimatedModel, TagFrame, ModelTag }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

# Sarge's animation.cfg, legs rows already shifted past the torso frames.
glob SARGE_ROWS: list[list[float]] = [
    [0.0, 30.0, 0.0, 20.0], [29.0, 1.0, 0.0, 20.0], [30.0, 30.0, 0.0, 20.0], [59.0, 1.0, 0.0, 20.0],
    [60.0, 30.0, 0.0, 20.0], [89.0, 1.0, 0.0, 20.0], [90.0, 40.0, 0.0, 18.0], [130.0, 6.0, 0.0, 15.0],
    [136.0, 6.0, 0.0, 15.0], [142.0, 5.0, 0.0, 20.0], [147.0, 4.0, 0.0, 20.0], [151.0, 1.0, 0.0, 15.0],
    [152.0, 1.0, 0.0, 15.0], [90.0, 8.0, 8.0, 20.0], [98.0, 12.0, 12.0, 20.0], [110.0, 11.0, 11.0, 21.0],
    [121.0, 10.0, 10.0, 20.0], [131.0, 10.0, 10.0, 15.0], [141.0, 10.0, 0.0, 18.0], [151.0, 6.0, 0.0, 20.0],
    [157.0, 8.0, 0.0, 15.0], [165.0, 1.0, 0.0, 15.0], [166.0, 10.0, 10.0, 15.0], [176.0, 8.0, 8.0, 15.0],
    [184.0, 7.0, 7.0, 15.0]
];

def tag(name: str, origin: Vec3) -> ModelTag {
    return ModelTag(name=name, origin=origin, axes=[Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)]);
}

def part(name: str, tags: list[ModelTag], frames: int = 200) -> ModelResource {
    model = AnimatedModel();
    for i in range(frames) {
        model.tags.append(TagFrame(tags=tags));
    }
    return ModelResource(name=name, model=model, skins=[]);
}

def sarge() -> PlayerRig {
    return dress_rig(
        rig_clips(SARGE_ROWS),
        part("lower", [tag("tag_torso", Vec3(z=10.0))]),
        part("upper", [tag("tag_head", Vec3(z=20.0)), tag("tag_weapon", Vec3(x=8.0, z=5.0))]),
        part("head", [], 1)
    );
}

def pose(rig: PlayerRig, seconds: float, step: float = 0.01, wish: Vec3 = Vec3(), velocity: Vec3 = Vec3(),
    grounded: bool = True, shots: int = -1, alive: bool = True, ready: bool = True, switching: str = "") -> list[str] {
    sounds: list[str] = [];
    for tick in range(int(seconds / step + 0.5)) {
        walker_result = rig spawn PoseRig(dt=step, wish=wish, velocity=velocity, grounded=grounded,
            shots=shots, alive=alive, ready=ready, switching=switching);
        sounds.extend(walker_result.sounds);
    }
    return sounds;
}

test "lerp frames play each sequence at its own rate, loop its tail and hold the end" {
    clips = rig_clips(SARGE_ROWS);
    # CG_ParseAnimationFile derives backward crouch and walk sequences.
    assert len(clips) == 27 and clips[ANIM_LEGS_BACKWALK].reversed and clips[ANIM_LEGS_BACKWALK].first == 98;
    run = LerpFrame();
    now = 0.0;
    run_lerp_frame(clips, run, ANIM_LEGS_RUN, 0, now, 1.0);
    frames: list[int] = [];
    for tick in range(120) {
        now += 0.01;
        run_lerp_frame(clips, run, ANIM_LEGS_RUN, 0, now, 1.0);
        if not frames or frames[-1] != run.frame {
            frames.append(run.frame);
        }
    }
    # LEGS_RUN's 11 frames at 21 fps: about 25 frame steps in 1.2 s, looping.
    assert len(frames) >= 24 and len(frames) <= 27;
    assert min(frames) == 110 and max(frames) == 120;
    # A non-looping sequence stops on its last frame.
    death = LerpFrame();
    now = 0.0;
    for tick in range(300) {
        now += 0.01;
        run_lerp_frame(clips, death, ANIM_BOTH_DEATH1, 0, now, 1.0);
    }
    assert death.frame == 29 and death.backlerp == 0.0;
    # A new sequence blends in from the frame on show rather than popping.
    shown = run.frame;
    run_lerp_frame(clips, run, ANIM_LEGS_IDLE, 0, 1.3, 1.0);
    assert run.old_frame == shown or run.frame == shown;
}

test "animation.cfg keywords set the head offset and fix the legs or torso" {
    settings = animation_settings(
        "sex\tf\nheadoffset -22 0 -3\nfixedlegs\nfixedtorso // still\nfootsteps boot\n0 30 0 20 // BOTH_DEATH1\n29 1 0 20\n"
    );
    assert settings.sex == "f" and settings.footsteps == "boot";
    assert settings.head_offset.x == -22.0 and settings.head_offset.z == -3.0;
    assert settings.fixed_legs and settings.fixed_torso;
    assert len(settings.frames) == 2 and settings.frames[0] == [0.0, 30.0, 0.0, 20.0];
    plain = animation_settings("sex m\n0 30 0 20\n");
    assert not plain.fixed_legs and not plain.fixed_torso and plain.head_offset.length() == 0.0;
    # CG_PlayerAngles: fixed legs keep the torso's yaw with no lean; a fixed
    # torso takes none of the view's pitch.
    rig = sarge();
    pose(rig, 1.0, wish=Vec3(y=1.0), velocity=Vec3(y=320.0));
    assert abs(rig.legs_angles.y - 45.0) < 1.5 and rig.legs_angles.x != 0.0;
    fixed = sarge();
    fixed.fixed_legs = True;
    fixed.fixed_torso = True;
    pose(fixed, 1.0, wish=Vec3(y=1.0), velocity=Vec3(y=320.0));
    assert abs(fixed.legs_angles.y - 11.25) < 1.5 and fixed.legs_angles.x == 0.0 and fixed.legs_angles.z == 0.0;
    assert abs(fixed.torso_angles.y) < 0.001;
    for tick in range(100) {
        fixed spawn PoseRig(dt=0.01, pitch=math.radians(-40.0));
    }
    assert abs(fixed.torso_angles.x) < 0.001 and abs(fixed.head_angles.x) > 30.0;
}

test "swinging angles lag, catch up and never trail by more than the clamp" {
    first = swing_angle(30.0, 40.0, 90.0, 300.0, 0.0, False, 0.01);
    assert first[0] == 0.0 and not first[1];
    moving = swing_angle(60.0, 40.0, 90.0, 300.0, 0.0, False, 0.01);
    assert moving[1] and abs(moving[0] - 6.0) < 0.001;
    clamped = swing_angle(150.0, 40.0, 90.0, 300.0, 0.0, True, 0.01);
    assert abs(clamped[0] - 61.0) < 0.001;
    assert movement_dir(1, 0, 0) == 0 and movement_dir(1, -1, 0) == 1 and movement_dir(0, -1, 0) == 2;
    assert movement_dir(-1, 1, 0) == 5 and movement_dir(0, 1, 0) == 6 and movement_dir(0, 0, 6) == 7;
}

test "legs run forwards, backpedal and turn toward the direction of travel" {
    rig = sarge();
    pose(rig, 0.5, wish=Vec3(x=1.0), velocity=Vec3(x=320.0));
    assert rig.legs_anim == ANIM_LEGS_RUN and rig.move_dir == 0;
    assert rig.legs.frame >= 110 and rig.legs.frame <= 120;
    # The legs lean into the run (CG_PlayerAngles: speed * 0.05 degrees).
    assert abs(rig.legs_angles.x - 16.0) < 0.1;
    rig = sarge();
    pose(rig, 0.5, wish=Vec3(x=-1.0), velocity=Vec3(x=-320.0));
    assert rig.legs_anim == ANIM_LEGS_BACK and rig.move_dir == 4;
    rig = sarge();
    # Strafing left: the legs swing 45 degrees toward it, the torso a quarter.
    pose(rig, 1.0, wish=Vec3(y=1.0), velocity=Vec3(y=320.0));
    assert rig.move_dir == 2 and rig.legs_anim == ANIM_LEGS_RUN;
    assert abs(rig.legs_angles.y - 45.0) < 1.5;
    assert abs(rig.torso_angles.y - (11.25 - 45.0)) < 1.5;
    # Standing, a view turned past 40 degrees shuffles the feet.
    rig = sarge();
    pose(rig, 0.3);
    assert rig.legs_anim == ANIM_LEGS_IDLE;
    rig spawn PoseRig(dt=0.01, yaw=math.radians(90.0));
    assert rig.legs.animation == ANIM_LEGS_TURN;
}

test "jumps, landings and footsteps cue the character's sounds" {
    rig = sarge();
    rig.voice = "sound/player/sarge/";
    rig.footsteps = "boot";
    sounds = pose(rig, 1.0, wish=Vec3(x=1.0), velocity=Vec3(x=320.0));
    # PM_Footsteps: a running step every 320 ms.
    assert sounds.count("step") == 3;
    assert rig_sound(rig, "step").startswith("sound/player/footsteps/boot");
    sounds = pose(rig, 0.01, wish=Vec3(x=1.0), velocity=Vec3(x=320.0, z=270.0), grounded=False);
    assert sounds == ["jump"] and rig.legs_anim == ANIM_LEGS_JUMP;
    pose(rig, 0.5, wish=Vec3(x=1.0), velocity=Vec3(x=320.0, z=-500.0), grounded=False);
    sounds = pose(rig, 0.01, wish=Vec3(x=1.0), velocity=Vec3(x=320.0), grounded=True);
    # 500 units/s: delta 25, a short fall's landing thud.
    assert sounds == ["land"] and rig.legs_anim == ANIM_LEGS_LAND;
    assert rig_sound(rig, "fall_far") == "sound/player/sarge/fall1.wav";
    assert rig_sound(rig, "pain50") == "sound/player/sarge/pain50_1.wav";
}

test "the torso attacks per shot, stands when ready, and drops and raises on a switch" {
    rig = sarge();
    hold_kit(rig, WeaponKit(key="railgun"));
    pose(rig, 0.05, shots=1, ready=False);
    assert rig.torso_anim == ANIM_TORSO_ATTACK and rig.torso.animation == ANIM_TORSO_ATTACK;
    assert rig.clock - rig.flash_time < 0.06;
    # The attack holds its last frame until the weapon is ready again.
    pose(rig, 1.0, shots=1, ready=False);
    assert rig.torso_anim == ANIM_TORSO_ATTACK;
    pose(rig, 0.05, shots=1, ready=True);
    assert rig.torso_anim == ANIM_TORSO_STAND;
    pose(rig, 0.1, shots=1, switching="drop");
    assert rig.torso_anim == ANIM_TORSO_DROP;
    hold_kit(rig, WeaponKit(key="gauntlet"));
    pose(rig, 0.1, shots=1, switching="raise");
    assert rig.torso_anim == ANIM_TORSO_RAISE;
    pose(rig, 0.1, shots=2, ready=False);
    assert rig.torso_anim == ANIM_TORSO_ATTACK2;
    pose(rig, 0.3, shots=2);
    assert rig.torso_anim == ANIM_TORSO_STAND2;
    rig spawn PoseRig(dt=0.01, gesture=True);
    assert rig.torso_anim == ANIM_TORSO_GESTURE and rig.torso_timer > 2.0;
}

test "deaths pick one of three sequences and hold its dead pose" {
    seen: list[int] = [];
    for seed in range(1, 12) {
        rig = sarge();
        rig.random = (seed * 1103515245 + 12345) % 2147483647;
        sounds = pose(rig, 2.0, alive=False);
        assert rig.legs_anim == rig.torso_anim and rig.legs_anim in [0, 2, 4];
        assert sounds == ["death" + str(rig.legs_anim // 2 + 1)];
        # The last frame of the fall is held.
        assert rig.legs.frame == rig.clips[rig.legs_anim].first + 29;
        if rig.legs_anim not in seen {
            seen.append(rig.legs_anim);
        }
        pose(rig, 0.01);
        assert rig.alive and rig.legs_anim == ANIM_LEGS_IDLE;
    }
    assert len(seen) == 3;
}

test "rigs join their parts through the tags and hold their weapon, barrel and flash" {
    world = World();
    area = Area(name="0", bounds=AABB(mins=Vec3(), maxs=Vec3()));
    world ++> area;
    rig = sarge();
    body = Corpse(pos=Vec3(x=100.0), yaw=0.0, body=rig);
    body +>:HasVisual:+> rig;
    move_to_area(body, area);
    kit = WeaponKit(key="machinegun");
    gun = part("gun", [tag("tag_barrel", Vec3(x=4.0)), tag("tag_flash", Vec3(x=20.0))], 1);
    kit +>:KitPart(role="weapon"):+> gun;
    kit +>:KitPart(role="barrel"):+> part("barrel", [], 1);
    kit +>:KitPart(role="flash"):+> part("flash", [], 1);
    hold_kit(rig, kit);
    draws = (world spawn GatherModels()).draws;
    names = [draw.resource.name for draw in draws];
    assert names == ["lower", "upper", "head", "gun", "barrel"];
    # tag_torso lifts the torso 10, tag_head the head a further 20.
    assert draws[1].origin.sub(Vec3(x=100.0, z=10.0)).length() < 0.001;
    assert draws[2].origin.sub(Vec3(x=100.0, z=30.0)).length() < 0.001;
    assert draws[3].origin.sub(Vec3(x=108.0, z=15.0)).length() < 0.001;
    # A shot shows the flash at tag_flash for a moment.
    pose(rig, 0.01, shots=1);
    names = [draw.resource.name for draw in (world spawn GatherModels()).draws];
    assert "flash" in names;
    pose(rig, 0.1, shots=1);
    names = [draw.resource.name for draw in (world spawn GatherModels()).draws];
    assert "flash" not in names;
}

test "a respawning body leaves its corpse, which sinks and goes" {
    world = World();
    area = Area(name="0", bounds=AABB(mins=Vec3(), maxs=Vec3()));
    world ++> area;
    for i in range(10) {
        rig = sarge();
        owner = Corpse(pos=Vec3(x=float(i) * 50.0, z=30.0), body=rig);
        move_to_area(owner, area);
        pose(rig, 0.5, alive=False);
        assert leave_corpse(world, owner, rig) is not None;
    }
    # BODY_QUEUE_SIZE keeps the eight newest.
    bodies = [world->:HasCorpse:->][?:Corpse];
    assert len(bodies) == 8 and min([body.order for body in bodies]) == 2;
    for tick in range(400) {
        world spawn CorpseTick(dt=0.01);
    }
    assert len([world->:HasCorpse:->][?:Corpse]) == 8;
    assert abs(bodies[0].pos.z - 30.0) < 0.001 and not bodies[0].body.alive;
    for tick in range(300) {
        world spawn CorpseTick(dt=0.01);
    }
    assert not [world->:HasCorpse:->][?:Corpse];
    assert abs(bodies[0].pos.z - 15.0) < 0.2;
}

test "a quad-carrying body is drawn again in the quad shell" {
    world = World();
    area = Area(name="0", bounds=AABB(mins=Vec3(), maxs=Vec3()));
    world ++> area;
    rig = sarge();
    carrier = Player(health=100, pos=Vec3(x=100.0));
    carrier +>:HasVisual:+> rig;
    move_to_area(carrier, area);
    carrier spawn GrantPowerup(kind="quad", duration=30.0);
    draws = (world spawn GatherModels()).draws;
    shells = [draw for draw in draws if draw.shader == "shader:powerups/quad"];
    assert len(draws) == 6 and len(shells) == 3 and shells[0].inflate == 3.0;
    carrier spawn GrantPowerup(kind="invisibility", duration=30.0);
    draws = (world spawn GatherModels()).draws;
    assert len(draws) == 3 and all([draw.shader == "shader:powerups/invisibility" for draw in draws]);
}
