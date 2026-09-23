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
import from .bot_character { BotCharacter }
import from .powerups { damage_scale, fire_interval_scale }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3, forward_from, right_from }

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

"""BotChangeViewAngles: each think turns the view by the remaining angle times
the view factor, capped at the maximum change per second."""
def turn_view(bot: Opponent, mind: BotCharacter, target: Vec3, seconds: float) {
    toward = target.sub(bot.pos);
    ideal_yaw = math.atan2(toward.y, toward.x);
    ideal_pitch = math.atan2(toward.z, math.sqrt(toward.x * toward.x + toward.y * toward.y));
    limit = math.radians(max(1.0, mind.view_maxchange)) * seconds;
    yaw_gap = turn_between(bot.yaw, ideal_yaw);
    pitch_gap = turn_between(bot.pitch, ideal_pitch);
    yaw_step = min(abs(yaw_gap) * mind.view_factor, limit);
    pitch_step = min(abs(pitch_gap) * mind.view_factor, limit);
    bot.yaw += yaw_step if yaw_gap > 0.0 else -yaw_step;
    bot.pitch += pitch_step if pitch_gap > 0.0 else -pitch_step;
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
    if rule.slot - 1 < len(Q3_FIRE_SOUNDS) {
        request_sound(bot, Q3_FIRE_SOUNDS[rule.slot - 1]);
    }
    scale = damage_scale(bot, "q3");
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

walker BotTactics {
    has player: Player,
        collision: CollisionMap,
        state: CombatState,
        rules: list[WeaponRule],
        dt: float,
        world: World | None = None;

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
        if foe is None or not visible {
            here.enemy_sight = 0.0;
            here.fighting = False;
            return;
        }
        here.fighting = True;
        here.enemy_sight += dt;
        if here.enemy_sample <= 0.0 {
            # The enemy's motion is remembered every half second.
            here.enemy_sample = 0.5;
            here.enemy_velocity = foe.velocity.add(Vec3());
            here.enemy_origin = foe.pos.sub(Vec3(z=foe_height(foe, self.collision)));
        }
        gap = foe.pos.sub(here.pos);
        horizontal = math.sqrt(gap.x * gap.x + gap.y * gap.y);
        # Bots think at 10 Hz: weapon choice, aim point and view turning.
        here.think_wait -= dt;
        if here.think_wait <= 0.0 {
            here.think_wait += 0.1;
            chosen = choose_weapon(here, mind, self.rules, horizontal);
            if chosen != here.weapon_slot {
                here.weapon_slot = chosen;
                here.weapon_change = 0.0;
            }
            current = rule_for(self.rules, here.weapon_slot);
            if current is not None {
                here.aim_target = aim_point(here, mind, current, foe, self.collision);
            }
            turn_view(here, mind, here.aim_target, 0.1);
            self.move_in_combat(here, mind, foe, gap, horizontal);
        }
        rule = rule_for(self.rules, here.weapon_slot);
        if rule is None or not armed_with(here, rule) {
            return;
        }
        if self.ready_to_fire(here, mind, rule) {
            bot_fire(world, here, rule, self.player, self.collision, self.state);
        }
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

    """ai_dmq3.c BotAttackMove: keep the ideal attack distance, strafe with
    attack skill, and jump now and then as the character likes to."""
    def move_in_combat(bot: Opponent, mind: BotCharacter, foe: Player, gap: Vec3, horizontal: float) {
        if horizontal < 0.001 {
            return;
        }
        ahead = Vec3(x=gap.x / horizontal, y=gap.y / horizontal);
        wish = Vec3();
        ideal = 0.0 if bot.weapon_slot == 1 else IDEAL_ATTACKDIST;
        span = 0.0 if bot.weapon_slot == 1 else ATTACK_RANGE;
        if horizontal > ideal + span {
            wish = ahead;
        } elif horizontal < ideal - span {
            wish = ahead.scale(-1.0);
        }
        if mind.attack_skill > 0.3 {
            bot.strafe_wait -= 0.1;
            if bot.strafe_wait <= 0.0 {
                bot.strafe = -bot.strafe;
                bot.strafe_wait = 0.4 + (1.0 - mind.attack_skill) + bot_random(bot) * 0.6;
            }
            side = Vec3(x=-ahead.y, y=ahead.x).scale(bot.strafe);
            # Never strafe off a ledge the bot could not climb back from.
            origin = bot.pos.sub(Vec3(z=bot.eye_height));
            probe = origin.add(side.scale(40.0));
            floor = self.collision.trace_point(probe, probe.sub(Vec3(z=64.0)));
            if floor.fraction == 1.0 {
                bot.strafe = -bot.strafe;
                side = side.scale(-1.0);
            }
            wish = wish.add(side);
        }
        if wish.length() > 0.001 {
            bot.steering = wish.normalized();
        } else {
            bot.steering = Vec3();
        }
        if bot.grounded and bot.jump_wait <= 0.0 and bot_random(bot) < mind.jumper * 0.1 {
            bot.velocity.z = 270.0;
            bot.grounded = False;
            bot.jump_wait = 1.0;
        }
    }
}
