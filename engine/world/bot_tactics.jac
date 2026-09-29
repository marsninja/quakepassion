"""Q3 bot combat after ai_dmq3.c: BotChooseWeapon's choice by the
character's fuzzy weapon weights, BotAimAtEnemy's leading and accuracy error,
BotChangeViewAngles' limited turn speed, BotCheckAttack's reaction time, fire
throttle and field-of-fire test, and BotAttackMove's strafing, range keeping
and jumping. Shots use the real weapon rules: hitscan, rails, lightning and
live projectiles. The AI that decides what to do (bot_ai.jac) uses these, and
act_bot turns the view and pulls the trigger every frame."""
import math;
import from .world { World, Player }
import from .combat {
    Opponent,
    HasOpponent,
    CombatState,
    Projectile,
    HasProjectile,
    line_of_fire,
    strike,
    request_sound,
    WEAPON_SWITCH_TIME
}
import from .weapons { WeaponRule }
import from .inventory { quantity, AdjustInventory }
import from .particles { rail_trail, beam_trail, impact_spray, wall_impact }
import from .bot_character { BotCharacter, BotState }
import from .bot_weights { best_fight_weapon }
import from .powerups { damage_scale, fire_interval_scale, empowered }
import from .models { PlayerRig, WeaponKit }
import from .player_rig { hold_kit }
import from .body_queue { Corpse, damage_corpse }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3, forward_from, right_from }

"""The weapon kits a bot can hold, one edge per weapon."""
edge Arms: Opponent --> WeaponKit {
    has key: str = "";
}

"""Put the weapon a bot now holds in its body's hand."""
def hold_weapon(bot: Opponent, key: str) {
    bot.shown_weapon = key;
    rig = bot.visual;
    if not isinstance(rig, PlayerRig) {
        return;
    }
    links = [edge bot->:Arms:->];
    kits = [bot->:Arms:->][?:WeaponKit];
    for i in range(min(len(links), len(kits))) {
        if links[i].key == key {
            hold_kit(rig, kits[i]);
            return;
        }
    }
}

# ai_dmq3.c attack distances: keep IDEAL_ATTACKDIST, within ATTACKRANGE.
glob IDEAL_ATTACKDIST: float = 140.0,
    ATTACK_RANGE: float = 40.0;

glob Q3_FIRE_SOUNDS: list[str] = [
    "sound/weapons/melee/fstatck.wav",
    "sound/weapons/machinegun/machgf1b.wav",
    "sound/weapons/shotgun/sshotf1b.wav",
    "sound/weapons/grenade/grenlf1a.wav",
    "sound/weapons/rocket/rocklf1a.wav",
    "sound/weapons/lightning/lg_fire.wav",
    "sound/weapons/railgun/railgf1a.wav",
    "sound/weapons/plasma/hyprbf1a.wav",
    "sound/weapons/bfg/bfg_fire.wav"
];

def bot_random(bot: Opponent) -> float {
    bot.shot_random = (bot.shot_random * 48271) % 2147483647;
    return float(bot.shot_random) / 2147483647.0;
}

def bot_crandom(bot: Opponent) -> float {
    return bot_random(bot) * 2.0 - 1.0;
}

def armed_with(bot: Opponent, rule: WeaponRule) -> bool {
    if quantity(bot.inventory, "weapon_" + rule.key) <= 0 {
        return False;
    }
    return not rule.ammo or quantity(bot.inventory, rule.ammo) >= rule.cost;
}

"""ai_dmq3.c BotChooseWeapon: the weapon BotChooseBestFightWeapon rates
highest over the bot's `inventory` (BotUpdateInventory, with the enemy's
distance and height in a fight), or the current one while a weapon is still
being raised or lowered or when none rates above zero."""
def choose_weapon(bot: Opponent, mind: BotCharacter, inventory: list[int]) -> int {
    if bot.weapon_change < WEAPON_SWITCH_TIME {
        return bot.weapon_slot;
    }
    best = best_fight_weapon(mind.weapon_weights, mind.weapon_numbers, inventory);
    return best if best > 0 else bot.weapon_slot;
}

def rule_named(rules: list[WeaponRule], key: str) -> WeaponRule | None {
    for rule in rules {
        if rule.key == key {
            return rule;
        }
    }
    return None;
}

def rule_for(rules: list[WeaponRule], slot: int) -> WeaponRule | None {
    for rule in rules {
        if rule.slot == slot {
            return rule;
        }
    }
    return None;
}

def foe_height(foe: Player, collision: CollisionMap) -> float {
    return foe.eye_height if isinstance(foe, Opponent) else collision.eye_height;
}

"""Signed shortest turn from `a` to `b`, in radians."""
def turn_between(a: float, b: float) -> float {
    return math.atan2(math.sin(b - a), math.cos(b - a));
}

"""ai_dmq3.c BotAimAtEnemy: the point a bot means to hit, from its accuracy,
aim skill and the enemy's remembered motion."""
def aim_point(bot: Opponent, mind: BotCharacter, rule: WeaponRule, foe: Player, collision: CollisionMap) -> Vec3 {
    accuracy = mind.accuracy_for(rule.key);
    skill = mind.skill_for(rule.key);
    accuracy = max(0.0001, accuracy);
    origin = foe.pos.sub(Vec3(z=foe_height(foe, collision)));
    # Unskilled bots aim worse at an enemy that has just changed direction.
    if mind.aim_skill < 0.9
        and origin.sub(bot.enemy_origin).length() > 48.0
        and bot.enemy_velocity.dot(foe.velocity) < 0.0 {
        accuracy *= 0.7;
    }
    target = origin.add(Vec3(z=8.0));
    distance = target.sub(bot.pos).length();
    if rule.speed > 0.0 and skill > 0.5 {
        target = origin.add(foe.velocity.scale(distance / rule.speed)).add(Vec3(z=8.0));
    }
    # Splash weapons are aimed at the ground under a grounded enemy.
    if rule.splash > 0 and rule.speed > 0.0 and skill > 0.6 and foe.grounded {
        floor = collision.trace_point(target, target.sub(Vec3(z=64.0)));
        if not floor.start_solid and floor.fraction < 1.0 {
            ground = target.lerp(target.sub(Vec3(z=64.0)), floor.fraction);
            sight = collision.trace_point(bot.pos, ground.add(Vec3(z=4.0)));
            if sight.fraction == 1.0 {
                target = ground.add(Vec3(z=4.0));
            }
        }
    }
    miss = 1.0 - accuracy;
    target = target.add(
        Vec3(
            x=20.0 * bot_crandom(bot) * miss,
            y=20.0 * bot_crandom(bot) * miss,
            z=10.0 * bot_crandom(bot) * miss
        )
    );
    # The view turns toward the aim point with more error: instant-hit
    # weapons lose accuracy within 150 units, and below 0.8 accuracy the
    # direction takes up to 0.3 of random error per axis.
    toward = target.sub(bot.pos);
    reach = toward.length();
    if rule.speed <= 0.0 and rule.key != "gauntlet" {
        accuracy *= 0.6 + min(reach, 150.0) / 150.0 * 0.4;
    }
    view = toward.normalized();
    if accuracy < 0.8 and reach > 0.001 {
        view = Vec3(
            x=view.x + 0.3 * bot_crandom(bot) * (1.0 - accuracy),
            y=view.y + 0.3 * bot_crandom(bot) * (1.0 - accuracy),
            z=view.z + 0.3 * bot_crandom(bot) * (1.0 - accuracy)
        );
    }
    bot.bot_state.view_target = bot.pos.add(view.normalized().scale(max(reach, 1.0)));
    return target;
}

"""q_math.c AngleDifference, in degrees folded into [-180, 180)."""
def view_delta(a: float, b: float) -> float {
    value = (a - b) % 360.0;
    return value - 360.0 if value >= 180.0 else value;
}

"""Aim the bot's ideal view at a point (vectoangles; Quake pitch is positive
looking down)."""
def look_at(bot: Opponent, target: Vec3) {
    toward = target.sub(bot.pos);
    flat = math.sqrt(toward.x * toward.x + toward.y * toward.y);
    if flat < 0.001 and abs(toward.z) < 0.001 {
        return;
    }
    bot.bot_state.ideal_yaw = math.degrees(math.atan2(toward.y, toward.x)) % 360.0;
    bot.bot_state.ideal_pitch = -math.degrees(math.atan2(toward.z, flat));
}

"""ai_main.c BotChangeViewAngles, the "over reaction" model, for one server
frame of `seconds`: each view angle gains speed toward its ideal by the view
factor, overshoots a little, and is damped; against an enemy the character's
view factor and maximum change apply, otherwise a slow 0.05 and 360 a second."""
def change_view(state: BotState, mind: BotCharacter, enemy: bool, seconds: float) {
    factor = max(0.01, min(1.0, mind.view_factor)) if enemy else 0.05;
    maxchange = max(1.0, min(1800.0, mind.view_maxchange)) if enemy else 360.0;
    maxchange = max(maxchange, 240.0) * seconds;
    for axis in [0, 1] {
        current = state.yaw if axis == 0 else state.pitch;
        ideal = state.ideal_yaw if axis == 0 else state.ideal_pitch;
        speed = state.yaw_speed if axis == 0 else state.pitch_speed;
        desired = view_delta(current % 360.0, ideal % 360.0) * factor;
        speed += speed - desired;
        if speed > 180.0 {
            speed = maxchange;
        }
        if speed < -180.0 {
            speed = -maxchange;
        }
        current = (current + max(-maxchange, min(maxchange, speed))) % 360.0;
        speed *= 0.45 * (1.0 - factor);
        if axis == 0 {
            state.yaw = current;
            state.yaw_speed = speed;
        } else {
            # Pitch stays in (-180, 180].
            state.pitch = current - 360.0 if current > 180.0 else current;
            state.pitch_speed = speed;
        }
    }
}

# Q3 servers run bots at sv_fps 20; clients draw between the frames.
glob BOT_VIEW_FRAME: float = 0.05;

# bg_pmove.c PM_UpdateViewAngles clamps the pitch to 16000 short units.
glob PITCH_CLAMP: float = 16000.0 * 360.0 / 65536.0;

"""Turn a bot's view every tick: BotChangeViewAngles steps each 50 ms server
frame and the drawn view moves smoothly between frames, as cgame interpolates
entity angles. Anything else that turned the bot (a spawn or teleporter)
restarts the view from there."""
def steer_view(bot: Opponent, mind: BotCharacter, enemy: bool, dt: float) {
    state = bot.bot_state;
    yaw = math.degrees(bot.yaw) % 360.0;
    pitch = -math.degrees(bot.pitch);
    shown = state.from_yaw + view_delta(state.yaw, state.from_yaw) * min(1.0, state.view_wait / BOT_VIEW_FRAME);
    if not state.view_ready or abs(view_delta(yaw, shown)) > 1.0 {
        state.view_ready = True;
        state.yaw = yaw;
        state.pitch = pitch;
        state.from_yaw = yaw;
        state.from_pitch = pitch;
        state.yaw_speed = 0.0;
        state.pitch_speed = 0.0;
        state.view_wait = 0.0;
    }
    state.view_wait += dt;
    while state.view_wait >= BOT_VIEW_FRAME {
        state.view_wait -= BOT_VIEW_FRAME;
        state.from_yaw = state.yaw;
        state.from_pitch = state.pitch;
        change_view(state, mind, enemy, BOT_VIEW_FRAME);
    }
    blend = state.view_wait / BOT_VIEW_FRAME;
    bot.yaw = math.radians((state.from_yaw + view_delta(state.yaw, state.from_yaw) * blend) % 360.0);
    # The AI's own view may swing past straight down; the player's view is
    # held within PM_UpdateViewAngles' 16000 (about 87.9 degrees) either way.
    drawn = state.from_pitch + (state.pitch - state.from_pitch) * blend;
    bot.pitch = -math.radians(max(-PITCH_CLAMP, min(PITCH_CLAMP, drawn)));
}

"""BotMovementViewTarget: look at the point 300 units along the bot's route
(at eye height), or along its steering when it has no route."""
def look_ahead(bot: Opponent) {
    here_point = bot.pos.sub(Vec3(z=bot.eye_height));
    remaining = 300.0;
    for waypoint in bot.route {
        leg = waypoint.sub(here_point);
        span = leg.length();
        if span >= remaining {
            look_at(bot, here_point.add(leg.scale(remaining / span)).add(Vec3(z=bot.eye_height)));
            return;
        }
        remaining -= span;
        here_point = waypoint;
    }
    if bot.route {
        look_at(bot, here_point.add(Vec3(z=bot.eye_height)));
    } elif bot.steering.length() > 0.001 {
        look_at(bot, bot.pos.add(Vec3(x=bot.steering.x, y=bot.steering.y).scale(300.0)));
    }
}

"""The view's spread for one hitscan pellet (Q3 spreads bullets in a disc)."""
def spread_direction(bot: Opponent, forward: Vec3, rule: WeaponRule) -> Vec3 {
    if rule.spread <= 0.0 {
        return forward;
    }
    side = right_from(math.atan2(forward.y, forward.x));
    up = side.cross(forward).normalized();
    angle = bot_random(bot) * math.pi * 2.0;
    radius = bot_crandom(bot);
    return forward.add(side.scale(math.cos(angle) * radius * rule.spread))
        .add(up.scale(math.sin(angle) * radius * rule.vertical_spread))
        .normalized();
}

"""One trigger pull along the bot's current view."""
def bot_fire(
    world: World,
    bot: Opponent,
    rule: WeaponRule,
    human: Player,
    collision: CollisionMap,
    state: CombatState
) {
    forward = forward_from(bot.yaw, bot.pitch);
    if rule.ammo {
        bot.inventory spawn AdjustInventory(kind=rule.ammo, amount=-rule.cost);
    }
    bot.weapon_wait = rule.interval * fire_interval_scale(bot);
    bot.attack_flash = min(0.25, max(0.1, rule.interval));
    # EV_FIRE_WEAPON: the torso's attack and the muzzle flash.
    if isinstance(bot.visual, PlayerRig) {
        bot.visual.shots += 1;
    }
    if rule.slot - 1 < len(Q3_FIRE_SOUNDS) {
        request_sound(bot, Q3_FIRE_SOUNDS[rule.slot - 1]);
    }
    # G_Damage scales a handicapped attacker's damage by its maximum health.
    scale = damage_scale(bot, "q3") * float(min(100, bot.max_health)) / 100.0;
    start = bot.pos;
    if rule.speed > 0.0 {
        heading = forward;
        # g_missile.c fire_grenade lofts the throw a little.
        if rule.gravity {
            heading = forward.add(Vec3(z=0.2)).normalized();
        }
        world +>:HasProjectile:+> Projectile(
            pos=start.add(heading.scale(16.0)),
            velocity=heading.scale(rule.speed),
            damage=int(float(rule.damage) * scale),
            splash=int(float(rule.splash) * scale),
            radius=rule.radius,
            gravity=rule.gravity,
            remaining=rule.fuse if rule.gravity else 10.0,
            effect=rule.effect,
            hostile=True,
            owner=bot
        );
        return;
    }
    reach = min(rule.reach, 8192.0);
    if rule.key == "gauntlet" {
        reach = 64.0;
    }
    struck: list[Player] = [];
    totals: list[int] = [];
    bodies: list[Corpse] = [];
    wounds: list[int] = [];
    for pellet in range(max(1, rule.pellets)) {
        shot = spread_direction(bot, forward, rule);
        finish = start.add(shot.scale(reach));
        wall = collision.trace_point(start, finish);
        hit = line_of_fire(world, bot, human, start, finish, collision, wall.fraction);
        endpoint = start.lerp(finish, hit.fraction);
        if rule.piercing {
            rail_trail(world, start, endpoint);
        } elif rule.key == "lightning" {
            beam_trail(world, start, endpoint, "lightning");
        }
        if hit.actor is not None {
            # EV_BULLET_HIT_FLESH / EV_MISSILE_HIT: CG_Bleed, unseen on the
            # viewer's own body.
            if hit.actor is not human {
                impact_spray(world, endpoint, shot.scale(-1.0), True, rule.key);
            }
            found = False;
            for slot in range(len(struck)) {
                if struck[slot] is hit.actor {
                    totals[slot] += rule.damage;
                    found = True;
                }
            }
            if not found {
                struck.append(hit.actor);
                totals.append(rule.damage);
            }
        } elif hit.corpse is not None {
            body = hit.corpse;
            impact_spray(world, endpoint, shot.scale(-1.0), True, rule.key);
            if body not in bodies {
                bodies.append(body);
                wounds.append(0);
            }
            wounds[bodies.index(body)] += int(float(rule.damage) * scale);
        } elif wall.fraction < 1.0 and not wall.start_solid and rule.key != "gauntlet" {
            surface = collision.surface_class(wall);
            if surface < 2 {
                impact_spray(world, endpoint, wall.normal);
            }
            wall_impact(
                world, "q3", rule.key, endpoint, wall.normal, surface, wall.model
            );
        }
    }
    for slot in range(len(bodies)) {
        damage_corpse(world, bodies[slot], wounds[slot]);
    }
    for slot in range(len(struck)) {
        strike(
            struck[slot],
            int(float(totals[slot]) * scale),
            bot,
            source=start,
            means=rule.key,
            tally=state
        );
    }
}

"""ai_dmq3.c BotCheckAttack: whether the bot fires its `rule` weapon now at
its enemy. It waits out its reaction time (clamped to a second), a weapon
change and the fire throttle, fires the gauntlet only within 60 units, needs
the aim point inside its field of fire (120 degrees up close, 50 further)
and in sight, and holds a splash weapon whose shot would burst on something
within its radius short of the enemy."""
def ready_to_fire(bot: Opponent, mind: BotCharacter, rule: WeaponRule, foe: Player, collision: CollisionMap) -> bool {
    if bot.weapon_wait > 0.0
        or bot.enemy_sight < mind.reaction
        or bot.weapon_change < WEAPON_SWITCH_TIME
        or bot.throttle_wait > 0.0 {
        return False;
    }
    if bot.throttle_shoot <= 0.0 {
        if bot_random(bot) > mind.fire_throttle {
            bot.throttle_wait = mind.fire_throttle;
            return False;
        }
        bot.throttle_shoot = 1.0 - mind.fire_throttle;
    }
    toward = bot.aim_target.sub(bot.pos);
    distance = toward.length();
    if rule.key == "gauntlet" and distance > 60.0 {
        return False;
    }
    fov = math.radians(120.0 if distance < 100.0 else 50.0) * 0.5;
    wanted_yaw = math.atan2(toward.y, toward.x);
    wanted_pitch = math.atan2(toward.z, math.sqrt(toward.x * toward.x + toward.y * toward.y));
    if abs(turn_between(bot.yaw, wanted_yaw)) > fov or abs(turn_between(bot.pitch, wanted_pitch)) > fov {
        return False;
    }
    sight = collision.trace_point(bot.pos, bot.aim_target);
    if sight.start_solid or sight.fraction < 1.0 {
        return False;
    }
    # "if won't hit the enemy" a splash shot must not burst close by.
    if rule.splash > 0 and rule.radius > 0.0 {
        forward = forward_from(bot.yaw, bot.pitch);
        start = bot.pos.sub(forward.scale(12.0));
        shot = collision.trace_point(start, start.add(forward.scale(1000.0)));
        reach = shot.fraction * 1000.0;
        enemy_reach = foe.pos.sub(start).length();
        if reach < enemy_reach - 32.0 and reach < rule.radius and float(rule.splash) - 0.5 * reach * 0.5 > 0.0 {
            return False;
        }
    }
    return True;
}

"""Whether the bot can take a step along `direction` (BotMoveInDirection
refuses to walk into a wall or off a ledge)."""
def can_step(bot: Opponent, direction: Vec3, collision: CollisionMap) -> bool {
    origin = bot.pos.sub(Vec3(z=bot.eye_height));
    ahead = direction.normalized().scale(40.0);
    wall = collision.trace_point(origin.add(Vec3(z=8.0)), origin.add(ahead).add(Vec3(z=8.0)));
    if wall.start_solid or wall.fraction < 1.0 {
        return False;
    }
    probe = origin.add(ahead);
    floor = collision.trace_point(probe, probe.sub(Vec3(z=64.0)));
    return floor.fraction < 1.0;
}

"""ai_dmq3.c BotAttackMove. Below 0.2 attack skill the bot stands; up to
0.4 it only closes or opens the distance; above that it strafes, flipping
now and then after 0.4-0.6 s and whenever blocked, backs off at random,
and keeps the ideal distance. It jumps as its jumper characteristic likes
(at most once a second) and crouches as its croucher one does."""
def attack_move(bot: Opponent, mind: BotCharacter, foe: Player, collision: CollisionMap) {
    memory = bot.bot_state;
    now = memory.clock;
    bot.steering = Vec3();
    gap = foe.pos.sub(bot.pos);
    horizontal = math.sqrt(gap.x * gap.x + gap.y * gap.y);
    if mind.attack_skill < 0.2 {
        bot.crouched = False;
        return;
    }
    distance = gap.length();
    if horizontal < 0.001 {
        return;
    }
    forward = Vec3(x=gap.x / horizontal, y=gap.y / horizontal);
    backward = forward.scale(-1.0);
    jump = False;
    if memory.crouch_time < now - 1.0 {
        if bot_random(bot) < mind.jumper {
            jump = True;
        } elif bot_random(bot) < mind.croucher {
            memory.crouch_time = now + mind.croucher * 5.0;
        }
    }
    bot.crouched = memory.crouch_time > now;
    if bot.crouched {
        jump = False;
    }
    if jump {
        if memory.jump_time > now {
            jump = False;
        } else {
            memory.jump_time = now + 1.0;
        }
    }
    ideal = 0.0 if bot.weapon_slot == 1 else IDEAL_ATTACKDIST;
    span = 0.0 if bot.weapon_slot == 1 else ATTACK_RANGE;
    if mind.attack_skill <= 0.4 {
        if distance > ideal + span and can_step(bot, forward, collision) {
            bot.steering = forward;
        } elif distance < ideal - span and can_step(bot, backward, collision) {
            bot.steering = backward;
        }
    } else {
        memory.strafe_time += 0.1;
        change = 0.4 + (1.0 - mind.attack_skill) * 0.2;
        if mind.attack_skill > 0.7 {
            change += bot_crandom(bot) * 0.2;
        }
        # "some magic number": a 6.5% chance per think once due.
        if memory.strafe_time > change and bot_random(bot) > 0.935 {
            memory.strafe_right = not memory.strafe_right;
            memory.strafe_time = 0.0;
        }
        for attempt in range(2) {
            side = Vec3(x=forward.y, y=-forward.x);
            if memory.strafe_right {
                side = side.scale(-1.0);
            }
            if bot_random(bot) > 0.9 {
                side = side.add(backward);
            } elif distance > ideal + span {
                side = side.add(forward);
            } elif distance < ideal - span {
                side = side.add(backward);
            }
            if can_step(bot, side, collision) {
                bot.steering = side.normalized();
                break;
            }
            memory.strafe_right = not memory.strafe_right;
            memory.strafe_time = 0.0;
        }
    }
    if jump and bot.grounded {
        bot.velocity.z = 270.0;
        bot.grounded = False;
    }
}

"""What a Q3 bot does every frame between its thinks (bot_ai.jac thinks at
10 Hz): its weapon and fire timers, its view turned toward what its AI node
looks at (BotChangeViewAngles), and its trigger (BotCheckAttack in the
battle nodes that attack, or the movement's own shot for a rocket jump)."""
def act_bot(
    world: World,
    bot: Opponent,
    mind: BotCharacter,
    human: Player,
    collision: CollisionMap,
    state: CombatState,
    rules: list[WeaponRule],
    dt: float
) {
    memory = bot.bot_state;
    held = rule_for(rules, bot.weapon_slot);
    # PM_FinishWeaponChange: the new weapon appears once the old one is down.
    if held is not None and held.key != bot.shown_weapon and bot.weapon_change >= 0.2 {
        hold_weapon(bot, held.key);
    }
    bot.weapon_wait = max(0.0, bot.weapon_wait - dt);
    bot.weapon_change += dt;
    bot.throttle_wait = max(0.0, bot.throttle_wait - dt);
    bot.throttle_shoot = max(0.0, bot.throttle_shoot - dt);
    bot.enemy_sample -= dt;
    bot.jump_wait = max(0.0, bot.jump_wait - dt);
    foe = memory.enemy;
    if foe is not None {
        bot.enemy_sight += dt;
    }
    visible = foe is not None and foe.health > 0 and memory.sight;
    travel = memory.travel;
    # BotChangeViewAngles turns toward the node's ideal view: the aim point,
    # the enemy's last position in a chase, or the movement's.
    if memory.view_mode == "enemy" and visible {
        look_at(bot, memory.view_target);
    } elif memory.view_mode == "chase" {
        look_at(bot, memory.last_enemy_origin.add(Vec3(z=bot.eye_height)));
    } elif travel.view_set {
        # MOVERESULT_MOVEMENTVIEWSET: the movement needs this view.
        memory.ideal_yaw = travel.yaw;
        memory.ideal_pitch = travel.pitch;
    } elif memory.view_mode != "enemy" {
        look_ahead(bot);
    }
    steer_view(bot, mind, foe is not None, dt);
    rule = rule_for(rules, bot.weapon_slot);
    if rule is None or not armed_with(bot, rule) {
        return;
    }
    # A rocket jump fires as it jumps (EA_Attack from the movement).
    if travel.attack and rule.key == travel.weapon {
        if bot.weapon_wait <= 0.0 and bot.weapon_change >= WEAPON_SWITCH_TIME {
            bot_fire(world, bot, rule, human, collision, state);
        }
        return;
    }
    if memory.ainode in ["battle_fight", "battle_retreat", "battle_nbg"]
        and visible
        and foe is not None
        and ready_to_fire(bot, mind, rule, foe, collision) {
        bot_fire(world, bot, rule, human, collision, state);
    }
}
