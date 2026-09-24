"""Q3 bot combat after ai_dmq3.c. Every arena bot carries its original
character; this walker gives each one BotChooseWeapon's weighted weapon choice,
BotAimAtEnemy's leading and accuracy error, BotChangeViewAngles' limited turn
speed, BotCheckAttack's reaction time, fire throttle and field-of-fire test,
and BotAttackMove's strafing, range keeping and jumping. Shots use the real
weapon rules: hitscan, rails, lightning and live projectiles."""
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
import from .particles { rail_trail, beam_trail, impact_spray }
import from .bot_character { BotCharacter, BotState }
import from .powerups { damage_scale, fire_interval_scale, empowered }
import from .pickups { Pickup, HasPickup }
import from .bot_routes { NavMesh, HasNavMesh, reachable }
import from .arena_navigation { bot_wants }
import from .powerups { stored_kinds }
import from .models { PlayerRig, WeaponKit }
import from .player_rig { hold_kit }
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

"""BotChooseBestFightWeapon over fw_weap.c: the owned, loaded weapon with the
highest character weight; the lightning gun counts a tenth beyond 768 units."""
def choose_weapon(bot: Opponent, mind: BotCharacter, rules: list[WeaponRule], reach: float) -> int {
    best = 1;
    best_weight = -1;
    for rule in rules {
        if not armed_with(bot, rule) {
            continue;
        }
        weight = mind.weight_for(rule.key);
        if rule.key == "lightning" and reach > 768.0 {
            weight = int(float(weight) * 0.1);
        }
        if weight > best_weight {
            best_weight = weight;
            best = rule.slot;
        }
    }
    return best;
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
    return target.add(
        Vec3(
            x=20.0 * bot_crandom(bot) * miss,
            y=20.0 * bot_crandom(bot) * miss,
            z=10.0 * bot_crandom(bot) * miss
        )
    );
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
    bot.pitch = -math.radians(state.from_pitch + (state.pitch - state.from_pitch) * blend);
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

"""ai_dmq3.c BotAggression: how keen the bot is to fight, from its weapons,
ammo, health and armor and where the enemy stands."""
def bot_aggression(bot: Opponent, foe: Player, weapon: str) -> float {
    inventory = bot.inventory;
    horizontal = Vec3(x=foe.pos.x - bot.pos.x, y=foe.pos.y - bot.pos.y).length();
    if empowered(bot, "quad") and (weapon != "gauntlet" or horizontal < 80.0) {
        return 70.0;
    }
    if foe.pos.z - bot.pos.z > 200.0 {
        return 0.0;
    }
    if bot.health < 60 or (bot.health < 80 and bot.armor < 40) {
        return 0.0;
    }
    for choice in [
        ("bfg", "bfg", 7, 100.0),
        ("railgun", "slugs", 5, 95.0),
        ("lightning", "lightning", 50, 90.0),
        ("rocketlauncher", "rockets", 5, 90.0),
        ("plasmagun", "cells", 40, 85.0),
        ("grenadelauncher", "grenades", 10, 80.0),
        ("shotgun", "shells", 10, 50.0)
    ] {
        if quantity(inventory, "weapon_" + choice[0]) > 0 and quantity(inventory, choice[1]) > choice[2] {
            return choice[3];
        }
    }
    return 0.0;
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
        } elif wall.fraction < 1.0 and not wall.start_solid and rule.key != "gauntlet" {
            impact_spray(world, endpoint, wall.normal);
        }
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

"""The ai_dmnet.c battle nodes, simplified. A bot that sees its enemy fights
it with BotAttackMove, or retreats along its item route while shooting back
when it feels outgunned (BotWantsToRetreat), grabbing nearby items on the way
(Battle_NBG); when the enemy slips out of sight a keen bot chases its last
position (BotWantsToChase) and a reluctant one returns to its goals. Views
turn every tick (BotChangeViewAngles): at the aim point in battle, and along
the route otherwise (BotMovementViewTarget)."""
walker BotTactics {
    has player: Player,
        collision: CollisionMap,
        state: CombatState,
        rules: list[WeaponRule],
        dt: float,
        world: World | None = None,
        pickups: list[Pickup] = [],
        mesh: NavMesh | None = None,
        surveyed: bool = False;

    can begin with World entry {
        self.world = here;
        if self.dt > 0.0 and self.rules {
            visit [here->:HasOpponent:->];
        }
    }

    can fight with Opponent entry {
        mind = here.character;
        world = self.world;
        if not here.arena or here.health <= 0 or here.dormant or mind is None or world is None {
            return;
        }
        dt = self.dt;
        memory = here.bot_state;
        memory.clock += dt;
        held = rule_for(self.rules, here.weapon_slot);
        # PM_FinishWeaponChange: the new weapon appears once the old one is down.
        if held is not None and held.key != here.shown_weapon and here.weapon_change >= 0.2 {
            hold_weapon(here, held.key);
        }
        here.weapon_wait = max(0.0, here.weapon_wait - dt);
        here.weapon_change += dt;
        here.throttle_wait = max(0.0, here.throttle_wait - dt);
        here.throttle_shoot = max(0.0, here.throttle_shoot - dt);
        here.enemy_sample -= dt;
        here.jump_wait = max(0.0, here.jump_wait - dt);
        foe = here.foe;
        visible = False;
        if foe is not None and foe.health > 0 {
            sight = self.collision.trace_point(here.pos, foe.pos);
            visible = not sight.start_solid and sight.fraction == 1.0;
        }
        here.think_wait -= dt;
        thinking = here.think_wait <= 0.0;
        if thinking {
            here.think_wait += 0.1;
        }
        if foe is None or not visible {
            here.enemy_sight = 0.0;
            here.fighting = False;
            here.crouched = False;
            if thinking {
                self.lost_sight(here, foe);
            }
            chasing = memory.battle == "chase" and foe is not None;
            if chasing and memory.clock - memory.seen_time < 2.0 {
                # Battle_Chase keeps aiming where the enemy went for two seconds.
                look_at(here, memory.chase_target);
            } else {
                look_ahead(here);
            }
            steer_view(here, mind, chasing, dt);
            return;
        }
        here.enemy_sight += dt;
        memory.seen_time = memory.clock;
        memory.chase_target = foe.pos.add(Vec3());
        if here.enemy_sample <= 0.0 {
            # The enemy's motion is remembered every half second.
            here.enemy_sample = 0.5;
            here.enemy_velocity = foe.velocity.add(Vec3());
            here.enemy_origin = foe.pos.sub(Vec3(z=foe_height(foe, self.collision)));
        }
        gap = foe.pos.sub(here.pos);
        horizontal = math.sqrt(gap.x * gap.x + gap.y * gap.y);
        # Bots think at 10 Hz: battle node, weapon choice, aim point and moves.
        if thinking {
            chosen = choose_weapon(here, mind, self.rules, horizontal);
            if chosen != here.weapon_slot {
                here.weapon_slot = chosen;
                here.weapon_change = 0.0;
            }
            current = rule_for(self.rules, here.weapon_slot);
            if current is not None {
                here.aim_target = aim_point(here, mind, current, foe, self.collision);
            }
            self.choose_battle(here, foe);
            if memory.battle == "fight" {
                self.move_in_combat(here, mind, gap, horizontal);
            }
        }
        here.fighting = memory.battle == "fight";
        if not here.fighting {
            here.crouched = False;
        }
        # Retreating bots with attack skill keep aiming back at the enemy.
        if here.fighting or mind.attack_skill > 0.3 {
            look_at(here, here.aim_target);
        } else {
            look_ahead(here);
        }
        steer_view(here, mind, True, dt);
        rule = rule_for(self.rules, here.weapon_slot);
        if rule is None or not armed_with(here, rule) {
            return;
        }
        if self.ready_to_fire(here, mind, rule) {
            bot_fire(world, here, rule, self.player, self.collision, self.state);
        }
    }

    """Seek_LTG, Battle_Fight, Battle_Retreat and Battle_NBG deciding what to
    do about a visible enemy."""
    def choose_battle(bot: Opponent, foe: Player) {
        memory = bot.bot_state;
        was = memory.battle;
        keen = bot_aggression(bot, foe, bot.shown_weapon);
        if memory.battle in ["", "chase"] {
            memory.battle = "retreat" if keen < 50.0 else "fight";
        } elif memory.battle == "fight" {
            if keen < 50.0 {
                memory.battle = "retreat";
            }
        } elif memory.battle == "retreat" {
            if keen > 50.0 {
                memory.battle = "fight";
            } elif bot.arena_goal is None and bot.roam_goal is None {
                # "battle retreat: no way out" fights it out.
                memory.battle = "fight";
            } elif memory.clock >= memory.check_time {
                memory.check_time = memory.clock + 1.0;
                nearby = self.nearby_goal(bot, 150.0);
                if nearby is not None {
                    memory.battle = "nbg";
                    memory.nearby_goal = nearby;
                    memory.battle_time = memory.clock + 150.0 / 100.0 + 1.0;
                }
            }
        } elif memory.battle == "nbg" {
            goal = memory.nearby_goal;
            if goal is None
                or memory.clock > memory.battle_time
                or goal.sub(bot.pos).length() < 40.0 {
                memory.nearby_goal = None;
                memory.battle = "retreat" if keen < 50.0 else "fight";
            }
        }
        if memory.battle != was {
            # A new node picks its goal at once.
            bot.arena_goal_wait = 0.0;
            bot.route = [];
            bot.route_areas = [];
        }
    }

    """Enemy out of sight: Battle_Fight chases when the bot wants to, retreats
    give up after four seconds, chases after ten or on reaching the spot."""
    def lost_sight(bot: Opponent, foe: Player | None) {
        memory = bot.bot_state;
        was = memory.battle;
        if foe is None or foe.health <= 0 {
            memory.battle = "";
        } elif memory.battle == "fight" {
            keen = bot_aggression(bot, foe, bot.shown_weapon);
            if keen > 50.0 {
                memory.battle = "chase";
                memory.battle_time = memory.clock + 10.0;
            } else {
                memory.battle = "";
            }
        } elif memory.battle in ["retreat", "nbg"] {
            if memory.clock - memory.seen_time > 4.0 {
                memory.battle = "";
            }
        } elif memory.battle == "chase" {
            reached = memory.chase_target.sub(bot.pos).length() < 48.0;
            if memory.clock > memory.battle_time or reached {
                memory.battle = "";
            }
        }
        if memory.battle != "nbg" {
            memory.nearby_goal = None;
        }
        if memory.battle != was {
            bot.arena_goal_wait = 0.0;
            bot.route = [];
            bot.route_areas = [];
        }
    }

    """BotNearbyGoal: the closest item the bot wants within `range` hundredths
    of a second of travel (straight-line at run speed), reachable over the
    AAS."""
    def nearby_goal(bot: Opponent, range: float) -> Vec3 | None {
        world = self.world;
        if world is None {
            return None;
        }
        if not self.surveyed {
            self.surveyed = True;
            self.pickups = [world->:HasPickup:->][?:Pickup];
            meshes = [world->:HasNavMesh:->][?:NavMesh];
            self.mesh = meshes[0] if meshes else None;
        }
        reach = range / 100.0 * 320.0;
        holding = any([quantity(bot.inventory, held) > 0 for held in stored_kinds("q3")]);
        best: Vec3 | None = None;
        best_distance = reach;
        origin = bot.pos.sub(Vec3(z=bot.eye_height));
        for pickup in self.pickups {
            if not pickup.active or pickup.waiting_for_use {
                continue;
            }
            distance = pickup.pos.sub(origin).length();
            if distance >= best_distance or not bot_wants(bot, pickup.rule.kind, pickup.rule.amount, holding) {
                continue;
            }
            mesh = self.mesh;
            if mesh is not None and not reachable(mesh, origin, pickup.pos) {
                continue;
            }
            best_distance = distance;
            best = pickup.pos.add(Vec3(z=bot.eye_height));
        }
        return best;
    }

    """ai_dmq3.c BotCheckAttack."""
    def ready_to_fire(bot: Opponent, mind: BotCharacter, rule: WeaponRule) -> bool {
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
        return abs(turn_between(bot.yaw, wanted_yaw)) <= fov
            and abs(turn_between(bot.pitch, wanted_pitch)) <= fov;
    }

    """Whether the bot can take a step along `direction` (BotMoveInDirection
    refuses to walk into a wall or off a ledge)."""
    def can_step(bot: Opponent, direction: Vec3) -> bool {
        origin = bot.pos.sub(Vec3(z=bot.eye_height));
        ahead = direction.normalized().scale(40.0);
        wall = self.collision.trace_point(origin.add(Vec3(z=8.0)), origin.add(ahead).add(Vec3(z=8.0)));
        if wall.start_solid or wall.fraction < 1.0 {
            return False;
        }
        probe = origin.add(ahead);
        floor = self.collision.trace_point(probe, probe.sub(Vec3(z=64.0)));
        return floor.fraction < 1.0;
    }

    """ai_dmq3.c BotAttackMove. Below 0.2 attack skill the bot stands; up to
    0.4 it only closes or opens the distance; above that it strafes, flipping
    now and then after 0.4-0.6 s and whenever blocked, backs off at random,
    and keeps the ideal distance. It jumps as its jumper characteristic likes
    (at most once a second) and crouches as its croucher one does."""
    def move_in_combat(bot: Opponent, mind: BotCharacter, gap: Vec3, horizontal: float) {
        memory = bot.bot_state;
        now = memory.clock;
        bot.steering = Vec3();
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
            if distance > ideal + span and self.can_step(bot, forward) {
                bot.steering = forward;
            } elif distance < ideal - span and self.can_step(bot, backward) {
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
                if self.can_step(bot, side) {
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
}
