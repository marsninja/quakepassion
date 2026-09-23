"""Shared weapon simulation and graph-driven opponents."""
import math;
import from .particles { impact_spray, ParticleTick, rail_trail, beam_trail }
import from .navigation { RouteSearch, RouteQueue, walk_edge }
import from .opponent_rule { OpponentRule, AttackProfile, rule_profiles }
import from .weapons { WeaponRule }
import from .world { World, Player }
import from .damage { Damage, blast_strength }
import from .powerups { damage_scale, fire_interval_scale, empowered, speed_scale }
import from .arena { ChooseSpawn }
import from .inventory { Inventory, quantity, AdjustInventory }
import from .models { Visual }
import from .gibs { GibRule, gibs_at, throw_gibs }
import from .bot_routes { NavMesh, HasNavMesh, plan_route }
import from .bot_character { BotCharacter }
import from .speakers { Speaker }
import from .signals { Signal, HasSignal, Fire }
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap, Trace }
import from ..physics.movement { MovePlayer, step_slide, slide }
import from ..math.vec3 { Vec3, forward_from, right_from }

edge HasOpponent: World --> Opponent {}
node Opponent(Player) {
    has eye_height: float = 22.0;
    has rule: OpponentRule = OpponentRule(),
        activation: Signal = Signal(),
        dormant: bool = False,
        spawn_wait: float = -1.0,
        modeled: bool = False,
        home: Vec3 = Vec3(),
        attack_wait: float = 0.7,
        attack_flash: float = 0.0,
        attack_clock: float = -1.0,
        attack_event: int = 0,
        burst_count: int = 1,
        attack_melee: bool = False,
        alternate_melee: bool = False,
        attack_profile: int = -1,
        attack_target: Vec3 = Vec3(),
        attack_speaker: Speaker | None = None,
        melee_speaker: Speaker | None = None,
        speakers: list[Speaker] = [],
        speaker_paths: list[str] = [],
        shot_random: int = 1,
        respawn_wait: float = 0.0,
        arena: bool = False,
        visual: Visual = Visual(),
        animation: list[int] = [],
        idle_animation: list[int] = [],
        attack_animation: list[int] = [],
        melee_animation: list[int] = [],
        alternate_melee_animation: list[int] = [],
        profile_animations: list[list[int]] = [],
        pain_animation: list[int] = [],
        pain_animations: list[list[int]] = [],
        knockdown_animation: list[int] = [],
        death_animation: list[int] = [],
        profiles: list[AttackProfile] = [],
        pain_wait: float = 0.0,
        pain_cooldown: float = 0.0,
        pain_variant: int = 0,
        pain_down: bool = False,
        leaping: bool = False,
        pending_explosion: bool = False,
        successor: Opponent | None = None,
        sighted: bool = False,
        pose_name: str = "",
        last_seen: Vec3 = Vec3(),
        last_seen_height: float = 22.0,
        alert: float = 0.0,
        steering: Vec3 = Vec3(),
        animation_time: float = 0.0,
        decision_wait: float = 0.0,
        support_wait: float = 0.0,
        pursuing: bool = False,
        arena_origin: Vec3 = Vec3(),
        arena_goal: Vec3 | None = None,
        arena_goal_wait: float = 0.0,
        route: list[Vec3] = [],
        route_launches: list[Vec3] = [],
        route_areas: list[int] = [],
        route_search: RouteSearch | None = None,
        route_wait: float = 0.0,
        navigation_needed: bool = False,
        route_target: Vec3 = Vec3(),
        boss_phase: int = 0,
        boss_time: float = 0.0,
        foe: Player | None = None,
        roam_goal: Vec3 | None = None,
        game: str = "",
        skill: int = 1,
        ambush: bool = False,
        kind: str = "",
        resume_hunt: bool = False,
        gib_rule: GibRule | None = None,
        gibbed: bool = False,
        remains: int = 0,
        pending_gibs: int = -1,
        patrol_goal: Vec3 | None = None,
        holding: bool = False,
        patrol_wait: float = 0.0,
        patrol_speed: float = 0.0,
        walk_animation: list[int] = [],
        character: BotCharacter | None = None,
        weapon_slot: int = 2,
        weapon_wait: float = 0.0,
        weapon_change: float = 1.0,
        enemy_sight: float = 0.0,
        enemy_sample: float = 0.0,
        enemy_origin: Vec3 = Vec3(),
        enemy_velocity: Vec3 = Vec3(),
        aim_target: Vec3 = Vec3(),
        think_wait: float = 0.0,
        throttle_wait: float = 0.0,
        throttle_shoot: float = 0.0,
        strafe: float = 1.0,
        strafe_wait: float = 0.0,
        jump_wait: float = 0.0,
        fighting: bool = False,
        weapon_visual: Visual | None = None,
        shown_weapon: str = "";
}

# Q3 bg_pmove.c: dropping then raising a weapon before it can fire.
glob WEAPON_SWITCH_TIME: float = 0.45;

"""g_client.c ClientSpawn arms every Q3 player, bots included, with a
gauntlet, a machine gun and 100 bullets."""
def arm_bot(bot: Opponent) {
    bot.inventory spawn AdjustInventory(kind="weapon_gauntlet", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="weapon_machinegun", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="bullets", amount=100, capacity=200);
    bot.weapon_slot = 2;
    bot.weapon_wait = 0.0;
    bot.weapon_change = WEAPON_SWITCH_TIME;
    bot.fighting = False;
    bot.enemy_sight = 0.0;
}

"""Q1 ai.qc / Q2 g_ai.c FindTarget: idle monsters never notice beyond 1000 units,
need to face the target at mid range (500-1000), and at near range unless the
target just fired; melee range only needs visibility."""
def notices(watcher: Opponent, target: Vec3, distance: float, hostile: bool) -> bool {
    if distance >= 1000.0 {
        return False;
    }
    if distance < 120.0 {
        return True;
    }
    toward = target.sub(watcher.pos);
    toward.z = 0.0;
    facing = toward.length() < 0.001
        or toward.normalized().dot(forward_from(watcher.yaw, 0.0)) > 0.3;
    if distance < 500.0 {
        return facing or hostile;
    }
    return facing;
}

"""Time between attacks by skill: Q1 SUB_AttackFinished skips the wait on
Nightmare; Q2 M_CheckAttack halves the attack chance on Easy and doubles it
on Hard and above."""
def attack_pause(enemy: Opponent) -> float {
    if enemy.game == "q1" and enemy.skill >= 3 {
        return 0.0;
    }
    if enemy.game == "q2" {
        if enemy.skill <= 0 {
            return enemy.rule.interval * 2.0;
        }
        if enemy.skill >= 2 {
            return enemy.rule.interval * 0.5;
        }
    }
    return enemy.rule.interval;
}

obj CombatState {
    has cooldown: float = 0.0,
        flash: float = 0.0,
        hit_flash: float = 0.0,
        kills: int = 0,
        shots: int = 0,
        weapon: int = 1,
        target: Vec3 = Vec3(),
        impact_model: int = -1,
        game: str = "",
        rules: list[WeaponRule] = [],
        random_state: int = 1,
        impacts: list[WeaponImpact] = [],
        fallback: list[int] = [],
        grenade_phase: int = 0,
        grenade_clock: float = 0.0,
        grenade_remaining: float = 0.0,
        route_credit: float = 1.0,
        noise: float = 0.0,
        sighter: Opponent | None = None,
        sight_wait: float = 0.0,
        navigation: RouteQueue = RouteQueue(),
        navmesh: NavMesh | None = None,
        navmesh_checked: bool = False,
        rail_streak: int = 0,
        awards: list[str] = [];

    def random() -> float {
        self.random_state = (self.random_state * 48271) % 2147483647;
        return float(self.random_state) / 2147483647.0 * 2.0 - 1.0;
    }
}

# Finite ray versus actor box. A value of 1 means no hit before the endpoint.
def actor_fraction(
    start: Vec3,
    finish: Vec3,
    eye: Vec3,
    height: float,
    top_drop: float = 0.0,
    width: float = 16.0
) -> float {
    lo = eye.sub(Vec3(x=width, y=width, z=height + 24.0));
    hi = eye.add(Vec3(x=width, y=width, z=32.0 - height - top_drop));
    origins = [start.x, start.y, start.z];
    deltas = [finish.x - start.x, finish.y - start.y, finish.z - start.z];
    mins = [lo.x, lo.y, lo.z];
    maxs = [hi.x, hi.y, hi.z];
    enter = 0.0;
    leave = 1.0;
    for axis in range(3) {
        if abs(deltas[axis]) < 0.000001 {
            if origins[axis] < mins[axis] or origins[axis] > maxs[axis] {
                return 1.0;
            }
        } else {
            a = (mins[axis] - origins[axis]) / deltas[axis];
            b = (maxs[axis] - origins[axis]) / deltas[axis];
            enter = max(enter, min(a, b));
            leave = min(leave, max(a, b));
            if enter > leave {
                return 1.0;
            }
        }
    }
    return enter;
}

"""Whether a route waypoint is reached. Arena routes come from the AAS, whose
points sit at standing-origin height, so height gets a step's slack."""
def waypoint_reached(point: Vec3, origin: Vec3, loose: bool) -> bool {
    gap = point.sub(origin);
    if not loose {
        return gap.length() < 8.0;
    }
    return math.sqrt(gap.x * gap.x + gap.y * gap.y) < 12.0 and abs(gap.z) < 28.0;
}

# Profiles derive from the rule once per opponent; rules are immutable data.
def ensure_profiles(enemy: Opponent) {
    if not enemy.profiles {
        enemy.profiles = rule_profiles(enemy.rule);
    }
}

def melee_order(enemy: Opponent, index: int) -> int {
    order = 0;
    for i in range(index) {
        if enemy.profiles[i].kind == "melee" {
            order += 1;
        }
    }
    return order;
}

# Restore the compatibility selection flags from the chosen profile.
def select_profile(enemy: Opponent, index: int) {
    ensure_profiles(enemy);
    enemy.attack_profile = index;
    profile = current_profile(enemy);
    enemy.attack_melee = index >= 0 and profile.kind == "melee";
    enemy.alternate_melee = enemy.attack_melee and melee_order(enemy, index) == 1;
}

def profile_frames(enemy: Opponent, index: int) -> list[int] {
    if index >= 0
        and index < len(enemy.profile_animations)
        and enemy.profile_animations[index] {
        return enemy.profile_animations[index];
    }
    ensure_profiles(enemy);
    if index < 0 or index >= len(enemy.profiles) {
        return enemy.attack_animation;
    }
    if enemy.profiles[index].kind == "melee" {
        if melee_order(enemy, index) == 1 and enemy.alternate_melee_animation {
            return enemy.alternate_melee_animation;
        }
        if enemy.melee_animation {
            return enemy.melee_animation;
        }
    }
    return enemy.attack_animation;
}

def speaker_for(enemy: Opponent, path: str) -> Speaker | None {
    if not path {
        return None;
    }
    for i in range(len(enemy.speaker_paths)) {
        if enemy.speaker_paths[i] == path and i < len(enemy.speakers) {
            return enemy.speakers[i];
        }
    }
    return None;
}

def profile_speaker(enemy: Opponent) -> Speaker | None {
    profile = current_profile(enemy);
    speaker = speaker_for(enemy, profile.sound);
    if speaker is not None {
        return speaker;
    }
    return enemy.melee_speaker if profile.kind == "melee" else enemy.attack_speaker;
}

def request_sound(enemy: Opponent, path: str) {
    speaker = speaker_for(enemy, path);
    if speaker is not None {
        speaker.origin = enemy.pos.add(Vec3());
        speaker.requests += 1;
    }
}

def body_class(enemy: Opponent) -> str {
    return enemy.rule.movement if enemy.rule.movement in ["fly", "swim"] else "walk";
}

"""Infighting: whether a campaign monster turns on another monster that hurt
it. Q1 T_Damage: any other class, and soldiers even at their own kind. Q2
M_ReactToDamage: another class of the same walk/fly/swim type, unless the
attacker is a tank-class sprayer."""
def provoked(victim: Opponent, attacker: Opponent) -> bool {
    if victim.game == "q1" {
        return victim.kind != attacker.kind or victim.kind == "monster_army";
    }
    return body_class(victim) == body_class(attacker)
        and victim.kind != attacker.kind
        and attacker.kind not in ["monster_tank", "monster_supertank", "monster_makron", "monster_jorg"];
}

"""Retaliate against a provoking attacker. Q2 monsters also shoot back at an
attacker aiming at them, or otherwise join the attacker's fight; a foe of None
means the player."""
def react_to_damage(victim: Opponent, attacker: Opponent) {
    if victim.arena or attacker is victim or attacker is victim.foe or attacker.health <= 0 {
        return;
    }
    # Q1/Q2 oldenemy: a monster already hunting the player returns to it later.
    if victim.foe is None {
        victim.resume_hunt = victim.alert > 0.0;
    }
    if provoked(victim, attacker) or (victim.game == "q2" and attacker.foe is victim) {
        victim.foe = attacker;
        victim.last_seen = attacker.pos.add(Vec3());
        victim.last_seen_height = attacker.eye_height;
    } elif victim.game == "q2" {
        # Help a buddy: take up the attacker's own fight.
        rival = attacker.foe;
        victim.foe = rival;
        victim.last_seen = attacker.last_seen.add(Vec3());
        victim.last_seen_height = attacker.last_seen_height;
        if isinstance(rival, Opponent) {
            victim.last_seen = rival.pos.add(Vec3());
            victim.last_seen_height = rival.eye_height;
        }
    } else {
        return;
    }
    victim.alert = 8.0;
    victim.sighted = True;
    victim.decision_wait = 0.0;
}

"""Q2 and Q3 corpses stay shootable until they are gibbed; Q1 monster corpses
take no damage."""
def gibbable_corpse(enemy: Opponent) -> bool {
    return enemy.health <= 0
        and enemy.game != "q1"
        and enemy.gib_rule is not None
        and not enemy.gibbed
        and not enemy.dormant;
}

def burst(victim: Opponent, overkill: int) {
    victim.gibbed = True;
    victim.visual.visible = False;
    victim.pending_gibs = overkill;
    rule = victim.gib_rule;
    if rule is not None {
        request_sound(victim, rule.sound);
    }
}

def pain_length(enemy: Opponent) -> float {
    if enemy.pain_down {
        return enemy.rule.knockdown_duration;
    }
    if enemy.pain_variant > 0
        and enemy.pain_variant - 1 < len(enemy.rule.pain_variant_durations) {
        return enemy.rule.pain_variant_durations[enemy.pain_variant - 1];
    }
    return enemy.rule.pain_duration;
}

def damage_opponent(
    victim: Opponent,
    amount: int,
    inventory: Inventory | None = None,
    state: CombatState | None = None,
    bypass_armor: bool = False,
    attacker: Player | None = None,
    means: str = "",
    tally: CombatState | None = None
) -> int {
    if victim.dormant or victim.rule.script or victim.rule.decoration {
        return 0;
    }
    if victim.health <= 0 {
        if gibbable_corpse(victim) and amount > 0 {
            victim.remains -= amount;
            if gibs_at(victim.gib_rule, victim.remains) {
                burst(victim, -victim.remains);
            }
        }
        return 0;
    }
    damage = victim spawn Damage(
        amount=amount, bypass_armor=bypass_armor, attacker=attacker, means=means
    );
    if state is not None and damage.dealt > 0 {
        state.hit_flash = 0.15;
    }
    if damage.killed {
        # Q1/Q2 Killed counts every monster death, whoever caused it.
        if not victim.rule.inert {
            if state is not None {
                state.kills += 1;
            } elif tally is not None and not victim.arena {
                tally.kills += 1;
            }
        }
        victim.activation spawn Fire(inventory=inventory);
        victim.visual.visible = bool(victim.death_animation)
            and not victim.rule.vanish_on_death;
        victim.attack_clock = -1.0;
        victim.attack_flash = 0.0;
        victim.leaping = False;
        victim.pain_down = False;
        victim.pose_name = "death";
        victim.animation_time = 0.0;
        victim.respawn_wait = 1.7 if victim.arena else 3.0;
        victim.pending_explosion = victim.rule.death_splash > 0;
        victim.remains = -damage.overkill;
        if gibs_at(victim.gib_rule, victim.remains) {
            burst(victim, damage.overkill);
        } else {
            request_sound(victim, victim.rule.death_sound);
        }
        return damage.dealt;
    }
    if isinstance(attacker, Opponent) {
        react_to_damage(victim, attacker);
    }
    if damage.dealt <= 0 {
        return 0;
    }
    rule = victim.rule;
    if rule.pain_health_reset > 0 {
        victim.health = rule.pain_health_reset;
    }
    if damage.dealt < rule.pain_threshold {
        return damage.dealt;
    }
    if rule.knockdown_damage > 0
        and damage.dealt >= rule.knockdown_damage
        and not victim.pain_down {
        victim.pain_down = True;
        victim.pain_variant = 0;
        victim.attack_clock = -1.0;
        victim.leaping = False;
        victim.pain_wait = rule.knockdown_duration;
        victim.pain_cooldown = max(victim.pain_cooldown, rule.knockdown_duration);
        victim.attack_flash = 0.0;
        victim.attack_wait = max(victim.attack_wait, rule.knockdown_duration);
        victim.decision_wait = 0.0;
        if rule.pain_sounds {
            request_sound(
                victim, rule.pain_sounds[(victim.shot_random // 7919) % len(rule.pain_sounds)]
            );
        }
        return damage.dealt;
    }
    if victim.pain_cooldown > 0.0 or victim.pain_down {
        return damage.dealt;
    }
    if rule.pain_chance_scale > 0.0 {
        victim.shot_random = (victim.shot_random * 48271) % 2147483647;
        chance = float(victim.shot_random) / 2147483647.0 * rule.pain_chance_scale;
        if chance > float(damage.dealt) {
            return damage.dealt;
        }
    }
    victim.pain_variant = 0;
    for i in range(len(rule.pain_variant_damage)) {
        if damage.dealt <= rule.pain_variant_damage[i] {
            victim.pain_variant = i + 1;
            break;
        }
    }
    if rule.pain_variant_damage
        and victim.pain_variant == 0
        and len(rule.pain_variants) > len(rule.pain_variant_damage) {
        victim.pain_variant = len(rule.pain_variant_damage) + 1;
    }
    if rule.pain_variants and not rule.pain_variant_damage {
        victim.shot_random = (victim.shot_random * 48271) % 2147483647;
        victim.pain_variant = 1 + victim.shot_random % len(rule.pain_variants);
    }
    victim.attack_clock = -1.0;
    victim.leaping = False;
    victim.pain_wait = pain_length(victim);
    victim.pain_cooldown = rule.pain_interval;
    # combat.qc T_Damage: Nightmare monsters rarely return to pain frames.
    if victim.game == "q1" and victim.skill >= 3 {
        victim.pain_cooldown = max(victim.pain_cooldown, 5.0);
    }
    victim.attack_flash = 0.0;
    victim.attack_wait = max(victim.attack_wait, victim.pain_wait);
    victim.decision_wait = 0.0;
    if rule.pain_sounds {
        request_sound(
            victim, rule.pain_sounds[(victim.shot_random // 7919) % len(rule.pain_sounds)]
        );
    }
    return damage.dealt;
}

"""One hit from an opponent. Opponent victims (arena bots fighting each other,
or campaign monsters caught in infighting) go through the full opponent damage
path so they die, animate, score and retaliate."""
def strike(
    target: Player,
    amount: int,
    attacker: Opponent,
    source: Vec3 | None = None,
    means: str = "",
    tally: CombatState | None = None
) -> int {
    if isinstance(target, Opponent) {
        dealt = damage_opponent(target, amount, attacker=attacker, means=means, tally=tally);
        if dealt > 0 and target.arena {
            target.alert = max(target.alert, 8.0);
            target.last_seen = attacker.pos;
            target.foe = attacker;
        }
        return dealt;
    }
    result = target spawn Damage(
        amount=amount, source=source, attacker=attacker, means=means
    );
    return result.dealt;
}

walker Aim {
    has start: Vec3,
        finish: Vec3,
        height: float,
        fraction: float = 1.0,
        target: Opponent | None = None,
        ignore: Opponent | None = None;

    can begin with World entry {
        visit [here->:HasOpponent:->];
    }

    can test_target with Opponent entry {
        corpse = gibbable_corpse(here);
        if here is self.ignore
            or (here.health <= 0 and not corpse)
            or here.dormant
            or here.pain_down
            or here.rule.decoration {
            return;
        }
        # Q2 lowers a corpse's box top to -8; Q3 to the corpse height.
        hit = actor_fraction(
            self.start,
            self.finish,
            here.pos,
            here.eye_height,
            40.0 if corpse else 0.0,
            here.rule.width
        );
        if hit < self.fraction {
            self.fraction = hit;
            self.target = here;
        }
    }
}

"""The first actor a monster's line of fire meets before `limit`: the player or
any monster other than the shooter, as Q1 traceline and Q2 gi.trace hit
whatever stands in the way."""
obj LineHit {
    has actor: Player | None = None,
        fraction: float = 1.0;
}

def line_of_fire(
    world: World,
    shooter: Opponent,
    person: Player | None,
    start: Vec3,
    finish: Vec3,
    collision: CollisionMap,
    limit: float
) -> LineHit {
    result = LineHit(fraction=limit);
    if person is not None and person.health > 0 {
        hit = actor_fraction(start, finish, person.pos, collision.eye_height, collision.top_drop);
        if hit < result.fraction {
            result.actor = person;
            result.fraction = hit;
        }
    }
    query = world spawn Aim(
        start=start,
        finish=finish,
        height=collision.eye_height,
        fraction=result.fraction,
        ignore=shooter
    );
    if query.target is not None and query.fraction < result.fraction {
        result.actor = query.target;
        result.fraction = query.fraction;
    }
    return result;
}

obj WeaponImpact {
    has model: int = -1,
        amount: int = 0,
        origin: Vec3 = Vec3(),
        splash: int = 0,
        radius: float = 0.0,
        energy_burst: bool = False;
}

edge HasProjectile: World --> Projectile {}
node Projectile {
    has pos: Vec3,
        velocity: Vec3,
        damage: int,
        splash: int = 0,
        radius: float = 0.0,
        gravity: bool = False,
        remaining: float = 5.0;

    has beam_damage: int = 0,
        beam_radius: float = 0.0,
        burst_damage: int = 0,
        burst_radius: float = 0.0,
        beam_wait: float = 0.1,
        burst_wait: float = 0.0,
        phase: int = 0,
        beams: list[Vec3] = [],
        effect: str = "",
        age: float = 0.0,
        hostile: bool = False,
        trap: bool = False,
        homing: float = 0.0,
        homing_wait: float = 0.0,
        owner: Opponent | None = None,
        quarry: Player | None = None;
}

def selected_weapon(state: CombatState) -> WeaponRule {
    for rule in state.rules {
        if rule.slot == state.weapon {
            return rule;
        }
    }
    # Passion retains its existing two-weapon rules until its combat design resumes.
    return WeaponRule(
        slot=state.weapon,
        key="",
        name="Heavy" if state.weapon == 2 else "Basic",
        ammo="shells" if state.weapon == 2 else "",
        damage=50 if state.weapon == 2 else 15,
        interval=0.7 if state.weapon == 2 else 0.3,
        reach=4096.0
    );
}

def owns_weapon(player: Player, rule: WeaponRule) -> bool {
    return quantity(player.inventory, "weapon_" + rule.key) > 0
        or (rule.hand_thrown and quantity(player.inventory, rule.ammo) > 0);
}

def select_weapon(player: Player, state: CombatState, slot: int) -> bool {
    if state.grenade_phase > 0 {
        return False;
    }
    if not state.rules {
        if slot not in [1, 2] {
            return False;
        }
        state.weapon = slot;
        return True;
    }
    for rule in state.rules {
        if rule.slot == slot and owns_weapon(player, rule) {
            state.weapon = slot;
            return True;
        }
    }
    return False;
}

def fire_weapon(
    world: World, player: Player, collision: CollisionMap, state: CombatState
) -> bool {
    if player.health <= 0 or state.cooldown > 0.000001 {
        return False;
    }
    rule = selected_weapon(state);
    if rule.hand_thrown or (state.rules and not owns_weapon(player, rule)) {
        return False;
    }
    if rule.ammo and quantity(player.inventory, rule.ammo) < rule.cost {
        return False;
    }
    if rule.ammo {
        player.inventory spawn AdjustInventory(kind=rule.ammo, amount=-rule.cost);
    }
    scale = damage_scale(player, state.game);
    state.cooldown = rule.interval * fire_interval_scale(player);
    state.flash = 0.08;
    state.shots += 1;
    state.impact_model = -1;
    direction = forward_from(player.yaw, player.pitch);
    side = right_from(player.yaw);
    up = side.cross(direction).normalized();
    if rule.speed > 0.0 {
        velocity = direction.scale(rule.speed);
        if rule.gravity {
            velocity = velocity.add(Vec3(z=200.0));
        }
        world +>:HasProjectile:+> Projectile(
            pos=player.pos,
            velocity=velocity,
            damage=int(float(rule.damage) * scale),
            splash=int(float(rule.splash) * scale),
            radius=rule.radius,
            gravity=rule.gravity,
            remaining=rule.fuse,
            effect=rule.effect,
            beam_damage=int(float(rule.beam_damage) * scale),
            beam_radius=rule.beam_radius,
            burst_damage=int(float(rule.burst_damage) * scale),
            burst_radius=rule.burst_radius
        );
        state.target = player.pos;
        return True;
    }
    # Aggregate pellet damage before armor, death targets and kill credit.
    victims: list[Opponent] = [];
    amounts: list[int] = [];
    for pellet in range(rule.pellets) {
        shot = direction;
        if rule.spread > 0.0 {
            shot = shot.add(side.scale(state.random() * rule.spread)).add(
                up.scale(state.random() * rule.vertical_spread)
            );
        }
        finish = player.pos.add(shot.normalized().scale(rule.reach));
        wall = collision.trace_point(player.pos, finish);
        query = world spawn Aim(
            start=player.pos,
            finish=finish,
            height=collision.eye_height,
            fraction=wall.fraction
        );
        state.target = player.pos.lerp(finish, query.fraction);
        hits: list[Opponent] = [];
        if rule.piercing {
            for enemy in [world->:HasOpponent:->][?:Opponent] {
                if enemy.health > 0
                    and not enemy.dormant
                    and actor_fraction(player.pos, finish, enemy.pos, enemy.eye_height)
                        < wall.fraction {
                    hits.append(enemy);
                }
            }
        } elif query.target is not None {
            hits.append(query.target);
        }
        for victim in hits {
            fraction = actor_fraction(
                player.pos, finish, victim.pos, victim.eye_height
            );
            impact_spray(
                world,
                player.pos.lerp(finish, fraction),
                shot.normalized().scale(-1.0),
                True
            );
            victim.last_seen = player.pos;
            victim.last_seen_height = collision.eye_height;
            victim.alert = 8.0;
            if victim not in victims {
                victims.append(victim);
                amounts.append(0);
            }
            amounts[victims.index(victim)] += int(float(rule.damage) * scale);
        }
        if (not hits or rule.piercing) and wall.fraction < 1.0 {
            impact_spray(world, player.pos.lerp(finish, wall.fraction), wall.normal);
            state.impact_model = wall.model;
            state.impacts.append(
                WeaponImpact(
                    model=wall.model,
                    amount=int(float(rule.damage) * scale),
                    origin=player.pos.lerp(finish, wall.fraction)
                )
            );
        }
    }
    for i in range(len(victims)) {
        damage_opponent(
            victims[i], amounts[i], player.inventory, state, attacker=player, means=rule.key
        );
    }
    # g_weapon.c: every two railgun hits in a row earn Impressive; a miss
    # resets the count.
    if state.game == "q3" and rule.key == "railgun" {
        if victims {
            state.rail_streak += 1;
            if state.rail_streak >= 2 {
                state.rail_streak -= 2;
                state.awards.append("impressive");
            }
        } else {
            state.rail_streak = 0;
        }
    }
    return True;
}

# Input-driven weapons keep their timers on the fixed simulation clock.
def throw_hand_grenade(
    world: World,
    player: Player,
    collision: CollisionMap,
    state: CombatState,
    rule: WeaponRule,
    held: bool
) -> bool {
    change = player.inventory spawn AdjustInventory(kind=rule.ammo, amount=-rule.cost);
    if change.accepted != -rule.cost {
        return False;
    }
    speed = 400.0 + (3.0 - state.grenade_remaining) * (400.0 / 3.0);
    scale = damage_scale(player, state.game);
    grenade = Projectile(
        pos=player.pos,
        velocity=forward_from(player.yaw, player.pitch).scale(speed).add(Vec3(z=200.0)),
        damage=int(float(rule.damage) * scale),
        splash=int(float(rule.splash) * scale),
        radius=rule.radius,
        gravity=True,
        remaining=max(0.001, state.grenade_remaining),
        effect=rule.effect
    );
    state.shots += 1;
    state.flash = 0.08;
    state.cooldown = rule.interval * fire_interval_scale(player);
    if held {
        projectile_blast(world, grenade, player, collision, state);
    } else {
        world +>:HasProjectile:+> grenade;
    }
    state.grenade_phase = 4 if held else 0;
    state.grenade_clock = 0.0;
    state.grenade_remaining = 0.0;
    return True;
}

def fallback_weapon(player: Player, state: CombatState) -> bool {
    for slot in state.fallback {
        for rule in state.rules {
            if rule.slot != slot or not owns_weapon(player, rule) {
                continue;
            }
            if rule.avoid_underwater and player.water_depth > 1 {
                continue;
            }
            if not rule.ammo or quantity(player.inventory, rule.ammo) >= rule.cost {
                state.weapon = slot;
                state.cooldown = max(state.cooldown, 0.2);
                return True;
            }
        }
    }
    return False;
}

def weapon_input(
    world: World,
    player: Player,
    collision: CollisionMap,
    state: CombatState,
    held: bool,
    dt: float
) -> bool {
    if player.health <= 0 or dt <= 0.0 {
        return False;
    }
    rule = selected_weapon(state);
    if state.grenade_phase == 0 {
        if not held or state.cooldown > 0.000001 {
            return False;
        }
        if rule.ammo and quantity(player.inventory, rule.ammo) < rule.cost {
            fallback_weapon(player, state);
            return False;
        }
        if not rule.hand_thrown {
            return fire_weapon(world, player, collision, state);
        }
        if not owns_weapon(player, rule) {
            return False;
        }
        state.grenade_phase = 1;
        state.grenade_clock = 1.0;
        return False;
    }
    if state.grenade_phase == 4 {
        if not held {
            state.grenade_phase = 0;
        }
        return False;
    }
    if state.grenade_phase == 1 {
        state.grenade_clock = max(0.0, state.grenade_clock - dt);
        if state.grenade_clock > 0.000001 {
            return False;
        }
        state.grenade_phase = 2;
        state.grenade_remaining = 3.2;
        if not held {
            state.grenade_phase = 3;
            state.grenade_clock = 0.1;
        }
        return False;
    }
    state.grenade_remaining = max(0.0, state.grenade_remaining - dt);
    if state.grenade_remaining <= 0.000001 {
        return throw_hand_grenade(world, player, collision, state, rule, True);
    }
    if state.grenade_phase == 2 {
        if not held {
            state.grenade_phase = 3;
            state.grenade_clock = 0.1;
        }
        return False;
    }
    state.grenade_clock = max(0.0, state.grenade_clock - dt);
    if state.grenade_clock <= 0.000001 {
        return throw_hand_grenade(world, player, collision, state, rule, False);
    }
    return False;
}

def blast_actors(
    world: World,
    origin: Vec3,
    splash: int,
    radius: float,
    hostile: bool,
    player: Player,
    collision: CollisionMap,
    state: CombatState,
    direct: Player | None = None,
    attacker: Opponent | None = None
) {
    if splash <= 0 or radius <= 0.0 {
        return;
    }
    actors: list[Player] = [player];
    actors.extend(
        [
            enemy
            for enemy in [world->:HasOpponent:->][?:Opponent]
            if not enemy.dormant
        ]
    );
    for actor in actors {
        corpse = isinstance(actor, Opponent) and gibbable_corpse(actor);
        if actor is direct or (actor.health <= 0 and not corpse) {
            continue;
        }
        height = actor.eye_height
            if isinstance(actor, Opponent)
            else collision.eye_height;
        center = actor.pos.sub(Vec3(z=height - 4.0));
        distance = center.sub(origin).length();
        if distance >= radius {
            continue;
        }
        sight = collision.trace_point(origin, center);
        if sight.start_solid or sight.fraction < 1.0 {
            continue;
        }
        strength = blast_strength(state.game, splash, radius, distance);
        if actor is player and not hostile {
            strength *= 0.5;
        }
        if isinstance(actor, Opponent) {
            strength *= actor.rule.blast_scale;
        }
        amount = int(strength);
        if isinstance(actor, Opponent) {
            damage_opponent(
                actor,
                amount,
                player.inventory,
                None if hostile else state,
                attacker=attacker if hostile else player,
                means="splash",
                tally=state if hostile else None
            );
        } else {
            actor spawn Damage(
                amount=amount,
                means="splash",
                source=origin,
                attacker=attacker if hostile else player
            );
        }
        if amount > 0 and not corpse {
            actor.velocity = actor.velocity.add(
                center.sub(origin).normalized().scale(float(amount) * 4.0)
            );
            actor.grounded = False;
        }
    }
}

def projectile_blast(
    world: World,
    projectile: Projectile,
    player: Player,
    collision: CollisionMap,
    state: CombatState,
    direct: Player | None = None
) {
    if projectile.splash <= 0 or projectile.radius <= 0.0 {
        return;
    }
    blast_actors(
        world,
        projectile.pos,
        projectile.splash,
        projectile.radius,
        projectile.hostile,
        player,
        collision,
        state,
        direct,
        projectile.owner
    );
    state.impacts.append(
        WeaponImpact(
            origin=projectile.pos, splash=projectile.splash, radius=projectile.radius
        )
    );
}

# Exploding monsters damage everything nearby, including their own kind.
def death_explosion(
    world: World,
    enemy: Opponent,
    player: Player,
    collision: CollisionMap,
    state: CombatState
) {
    enemy.pending_explosion = False;
    origin = enemy.pos.sub(Vec3(z=enemy.eye_height - 4.0));
    blast_actors(
        world,
        origin,
        enemy.rule.death_splash,
        enemy.rule.death_radius,
        True,
        player,
        collision,
        state,
        enemy
    );
    state.impacts.append(
        WeaponImpact(
            origin=origin, splash=enemy.rule.death_splash, radius=enemy.rule.death_radius
        )
    );
}

def projectile_beams(
    world: World,
    projectile: Projectile,
    player: Player,
    collision: CollisionMap,
    state: CombatState
) {
    projectile.beams = [];
    if projectile.hostile {
        if player.health <= 0 {
            return;
        }
        center = player.pos.sub(Vec3(z=collision.eye_height - 4.0));
        if center.sub(projectile.pos).length() > projectile.beam_radius {
            return;
        }
        finish = projectile.pos.add(
            center.sub(projectile.pos).normalized().scale(2048.0)
        );
        trace = collision.trace_point(projectile.pos, finish);
        if trace.start_solid {
            return;
        }
        projectile.beams.append(projectile.pos.lerp(finish, trace.fraction));
        if actor_fraction(
            projectile.pos, finish, player.pos, collision.eye_height, collision.top_drop
        )
            < trace.fraction {
            player spawn Damage(amount=projectile.beam_damage, source=projectile.pos);
        }
        return;
    }
    actors = [
        enemy
        for enemy in [world->:HasOpponent:->][?:Opponent]
        if not enemy.dormant and enemy.health > 0
    ];
    for target in actors {
        center = target.pos.sub(Vec3(z=target.eye_height - 4.0));
        if center.sub(projectile.pos).length() > projectile.beam_radius {
            continue;
        }
        finish = projectile.pos.add(
            center.sub(projectile.pos).normalized().scale(2048.0)
        );
        trace = collision.trace_point(projectile.pos, finish);
        if trace.start_solid {
            continue;
        }
        projectile.beams.append(projectile.pos.lerp(finish, trace.fraction));
        for victim in actors {
            if actor_fraction(projectile.pos, finish, victim.pos, victim.eye_height)
                < trace.fraction {
                damage_opponent(
                    victim, projectile.beam_damage, player.inventory, state, attacker=player
                );
            }
        }
        if trace.fraction < 1.0 {
            state.impacts.append(
                WeaponImpact(
                    model=trace.model,
                    amount=projectile.beam_damage,
                    origin=projectile.pos.lerp(finish, trace.fraction)
                )
            );
        }
    }
}

# The delayed energy burst needs line of sight from both the orb and its owner.
def projectile_energy_burst(
    world: World,
    projectile: Projectile,
    player: Player,
    collision: CollisionMap,
    state: CombatState
) {
    if projectile.hostile {
        center = player.pos.sub(Vec3(z=collision.eye_height - 4.0));
        distance = center.sub(projectile.pos).length();
        sight = collision.trace_point(projectile.pos, center);
        if player.health > 0
            and distance < projectile.burst_radius
            and not sight.start_solid
            and sight.fraction >= 1.0 {
            player spawn Damage(
                amount=int(
                    float(projectile.burst_damage)
                        * (1.0 - math.sqrt(distance / projectile.burst_radius))
                ),
                means="splash",
                source=projectile.pos
            );
        }
        state.impacts.append(
            WeaponImpact(
                origin=projectile.pos,
                splash=projectile.burst_damage,
                radius=projectile.burst_radius,
                energy_burst=True
            )
        );
        return;
    }
    for victim in [world->:HasOpponent:->][?:Opponent] {
        if victim.dormant or victim.health <= 0 {
            continue;
        }
        center = victim.pos.sub(Vec3(z=victim.eye_height - 4.0));
        distance = center.sub(projectile.pos).length();
        if distance >= projectile.burst_radius {
            continue;
        }
        sight = collision.trace_point(projectile.pos, center);
        owner_sight = collision.trace_point(player.pos, center);
        if sight.start_solid
            or sight.fraction < 1.0
            or owner_sight.start_solid
            or owner_sight.fraction < 1.0 {
            continue;
        }
        amount = int(
            float(projectile.burst_damage)
                * (1.0 - math.sqrt(distance / projectile.burst_radius))
        );
        damage_opponent(victim, amount, player.inventory, state, attacker=player, means="splash");
    }
    state.impacts.append(
        WeaponImpact(
            origin=projectile.pos,
            splash=projectile.burst_damage,
            radius=projectile.burst_radius,
            energy_burst=True
        )
    );
}

walker ProjectileTick {
    has player: Player,
        collision: CollisionMap,
        state: CombatState,
        dt: float,
        world: World | None = None;

    can start with World entry {
        self.world = here;
        visit [here->:HasProjectile:->];
    }

    can move with Projectile entry {
        world = self.world;
        if world is None or self.dt <= 0.0 {
            return;
        }
        step = min(self.dt, here.remaining);
        here.age += step;
        here.remaining = max(0.0, here.remaining - self.dt);
        if here.phase > 0 {
            here.burst_wait = max(0.0, here.burst_wait - step);
            if here.phase == 1 and here.burst_wait <= 0.000001 {
                projectile_energy_burst(
                    world, here, self.player, self.collision, self.state
                );
                here.phase = 2;
            }
            if here.remaining <= 0.0 {
                world del --> here;
            }
            return;
        }
        # Homing pods retarget at the original 5 Hz cadence; a dead target ends pursuit.
        quarry: Player = self.player;
        if here.quarry is not None {
            quarry = here.quarry;
        }
        if here.hostile and here.homing > 0.0 and quarry.health > 0 {
            here.homing_wait = max(0.0, here.homing_wait - step);
            if here.homing_wait <= 0.000001 {
                here.homing_wait = 0.2;
                target = quarry.pos.sub(Vec3(z=12.0));
                here.velocity = target.sub(here.pos).normalized().scale(here.homing);
            }
        }
        if here.gravity {
            here.velocity.z -= 800.0 * step;
        }
        finish = here.pos.add(here.velocity.scale(step));
        wall = self.collision.trace_point(here.pos, finish);
        victim: Opponent | None = None;
        fraction = wall.fraction;
        player_hit = False;
        if here.hostile {
            hit = actor_fraction(
                here.pos,
                finish,
                self.player.pos,
                self.collision.eye_height,
                self.collision.top_drop
            );
            if self.player.health > 0 and hit < fraction {
                fraction = hit;
                player_hit = True;
            }
            # Monster missiles and world traps strike any monster but their owner.
            query = world spawn Aim(
                start=here.pos,
                finish=finish,
                height=self.collision.eye_height,
                fraction=fraction,
                ignore=here.owner
            );
            if query.target is not None and query.fraction < fraction {
                victim = query.target;
                fraction = query.fraction;
                player_hit = False;
            }
        } else {
            query = world spawn Aim(
                start=here.pos,
                finish=finish,
                height=self.collision.eye_height,
                fraction=wall.fraction
            );
            victim = query.target;
            fraction = query.fraction;
        }
        here.pos = here.pos.lerp(finish, fraction);
        if player_hit {
            self.player spawn Damage(
                amount=here.damage,
                source=here.pos.sub(here.velocity.normalized()),
                attacker=here.owner
            );
            projectile_blast(
                world,
                here,
                self.player,
                self.collision,
                self.state,
                self.player if here.damage > 0 else None
            );
            world del --> here;
            return;
        }
        if victim is not None {
            damage_opponent(
                victim,
                here.damage,
                self.player.inventory,
                None if here.hostile else self.state,
                attacker=here.owner if here.hostile else self.player,
                tally=self.state if here.hostile else None
            );
        } elif wall.fraction < 1.0
            and here.gravity
            and here.remaining > 0.0
            and not wall.start_solid {
            here.velocity = here.velocity.sub(
                wall.normal.scale(2.0 * here.velocity.dot(wall.normal))
            ).scale(
                0.5
            );
            here.pos = here.pos.add(wall.normal.scale(0.1));
            if wall.normal.z > 0.7 and here.velocity.length() < 40.0 {
                here.velocity = Vec3();
            }
            return;
        } elif wall.fraction >= 1.0 and here.remaining > 0.0 {
            if here.beam_damage > 0 {
                here.beam_wait -= step;
                if here.beam_wait <= 0.000001 {
                    projectile_beams(
                        world, here, self.player, self.collision, self.state
                    );
                    here.beam_wait = 0.1;
                }
            }
            return;
        }
        if victim is None and wall.fraction < 1.0 {
            here.pos = here.pos.add(wall.normal.scale(0.1));
            self.state.impacts.append(
                WeaponImpact(model=wall.model, amount=here.damage, origin=here.pos)
            );
        }
        # Nonexplosive missiles expire quietly at the end of their lifetime.
        projectile_blast(world, here, self.player, self.collision, self.state, victim);
        if here.burst_damage > 0 and (victim is not None or wall.fraction < 1.0) {
            # Original orb backs away from impact before its delayed burst.
            here.pos = here.pos.sub(here.velocity.scale(0.1));
            here.velocity = Vec3();
            here.beams = [];
            here.phase = 1;
            here.burst_wait = 0.1;
            here.remaining = 0.5;
        } else {
            world del --> here;
        }
    }
}

def load_opponent_signals(world: World, bsp: Bsp) {
    for index in range(len(bsp.entities)) {
        if bsp.entities[index].fields.get("classname", "").startswith("monster_") {
            world +>:HasSignal:+> Signal(entities=[index]);
        }
    }
}

# Without a selection, timing and aim follow the primary ranged sequence, as
# the single-attack definitions did.
def current_profile(enemy: Opponent) -> AttackProfile {
    ensure_profiles(enemy);
    if enemy.attack_profile >= 0 and enemy.attack_profile < len(enemy.profiles) {
        return enemy.profiles[enemy.attack_profile];
    }
    for profile in enemy.profiles {
        if profile.kind == "ranged" {
            return profile;
        }
    }
    if enemy.profiles {
        return enemy.profiles[0];
    }
    return AttackProfile(damage=enemy.rule.damage);
}

def melee_reach(enemy: Opponent) -> float {
    ensure_profiles(enemy);
    reach = 0.0;
    for profile in enemy.profiles {
        if profile.kind == "melee" {
            reach = max(reach, profile.reach);
        }
    }
    return reach;
}

def attack_times(enemy: Opponent) -> list[float] {
    return current_profile(enemy).times;
}

def attack_duration(enemy: Opponent) -> float {
    return current_profile(enemy).duration + float(enemy.burst_count - 1) * 0.1;
}

def attack_event_count(enemy: Opponent) -> int {
    return len(attack_times(enemy)) + enemy.burst_count - 1;
}

def attack_event_time(enemy: Opponent) -> float {
    if enemy.burst_count > 1 {
        return attack_times(enemy)[0] + float(enemy.attack_event) * 0.1;
    }
    return attack_times(enemy)[enemy.attack_event];
}

def attack_pose_time(enemy: Opponent) -> float {
    clock = enemy.attack_clock * 10.0;
    profile = current_profile(enemy);
    if profile.kind != "melee"
        and profile.hold_frame >= 0
        and clock >= float(profile.hold_frame) {
        clock -= min(float(enemy.burst_count - 1), clock - float(profile.hold_frame));
    }
    return clock;
}

# Weighted choice among sequences whose range brackets contain the target.
# Close attacks take priority, as in the original decision tables. Randomness
# is consumed only when more than one sequence qualifies.
def choose_attack(enemy: Opponent, distance: float) -> int {
    ensure_profiles(enemy);
    close: list[int] = [];
    far: list[int] = [];
    for i in range(len(enemy.profiles)) {
        profile = enemy.profiles[i];
        if profile.kind == "melee" {
            if distance <= profile.max_range {
                close.append(i);
            }
        } elif distance >= profile.min_range and distance <= profile.max_range {
            far.append(i);
        }
    }
    pool = close if close else far;
    if not pool {
        return -1;
    }
    if len(pool) == 1 {
        return pool[0];
    }
    total = 0.0;
    for i in pool {
        total += max(0.0, enemy.profiles[i].weight);
    }
    enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
    roll = float(enemy.shot_random) / 2147483647.0 * total;
    accumulated = 0.0;
    for i in pool {
        accumulated += max(0.0, enemy.profiles[i].weight);
        if roll < accumulated {
            return i;
        }
    }
    return pool[-1];
}

def rotate_yaw(direction: Vec3, degrees: float) -> Vec3 {
    if degrees == 0.0 {
        return direction;
    }
    angle = degrees * math.pi / 180.0;
    return Vec3(
        x=direction.x * math.cos(angle) - direction.y * math.sin(angle),
        y=direction.x * math.sin(angle) + direction.y * math.cos(angle),
        z=direction.z
    );
}

def opponent_aim(enemy: Opponent, player: Player, profile: AttackProfile) -> Vec3 {
    target = enemy.attack_target
        if profile.lock_aim
        else player.pos.sub(player.velocity.scale(profile.aim_lag));
    direction = target.sub(enemy.pos).normalized();
    if profile.aim_spread > 0.0 or profile.aim_vertical > 0.0 {
        side = right_from(math.atan2(direction.y, direction.x));
        up = side.cross(direction).normalized();
        enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
        horizontal = float(enemy.shot_random) / 2147483647.0 * 2.0 - 1.0;
        enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
        vertical = float(enemy.shot_random) / 2147483647.0 * 2.0 - 1.0;
        direction = direction.add(side.scale(horizontal * profile.aim_spread)).add(
            up.scale(vertical * profile.aim_vertical)
        ).normalized();
    }
    return direction;
}

# Enemy spread has its own saved stream; effects and AI cannot alter player spread.
def opponent_shot(
    world: World,
    enemy: Opponent,
    player: Player,
    collision: CollisionMap,
    profile: AttackProfile | None = None,
    yaw_offset: float = 0.0,
    person: Player | None = None,
    tally: CombatState | None = None
) {
    if profile is None {
        profile = current_profile(enemy);
    }
    if person is None and not isinstance(player, Opponent) {
        person = player;
    }
    direction = rotate_yaw(opponent_aim(enemy, player, profile), yaw_offset);
    side = right_from(math.atan2(direction.y, direction.x));
    up = side.cross(direction).normalized();
    # Q1 multidamage / Q2 fire_lead: pellets add up per actor before applying.
    struck: list[Player] = [];
    totals: list[int] = [];
    for i in range(profile.pellets) {
        shot = direction;
        if profile.spread > 0.0 {
            enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
            horizontal = float(enemy.shot_random) / 2147483647.0 * 2.0 - 1.0;
            enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
            vertical = float(enemy.shot_random) / 2147483647.0 * 2.0 - 1.0;
            shot = shot.add(side.scale(horizontal * profile.spread)).add(
                up.scale(
                    vertical
                        * (
                            profile.vertical_spread
                                if profile.vertical_spread >= 0.0
                                else profile.spread
                        )
                )
            );
        }
        finish = enemy.pos.add(shot.normalized().scale(8192.0));
        wall = collision.trace_point(enemy.pos, finish);
        if profile.rail {
            rail_trail(world, enemy.pos, enemy.pos.lerp(finish, wall.fraction));
        }
        hit = line_of_fire(world, enemy, person, enemy.pos, finish, collision, wall.fraction);
        if hit.actor is not None {
            amount = 6 if enemy.arena else profile.damage;
            found = False;
            for slot in range(len(struck)) {
                if struck[slot] is hit.actor {
                    totals[slot] += amount;
                    found = True;
                }
            }
            if not found {
                struck.append(hit.actor);
                totals.append(amount);
            }
        } elif wall.fraction < 1.0 and not wall.start_solid {
            impact_spray(world, enemy.pos.lerp(finish, wall.fraction), wall.normal);
        }
    }
    for slot in range(len(struck)) {
        strike(
            struck[slot],
            int(float(totals[slot]) * damage_scale(enemy, "q3" if enemy.arena else "")),
            enemy,
            source=enemy.pos,
            tally=tally
        );
    }
}

# Instant beams stop at world geometry; a hit needs the target box before it.
def opponent_beam(
    world: World,
    enemy: Opponent,
    player: Player,
    collision: CollisionMap,
    profile: AttackProfile,
    amount: int,
    person: Player | None = None,
    tally: CombatState | None = None
) {
    if person is None and not isinstance(player, Opponent) {
        person = player;
    }
    origin = enemy.pos.add(Vec3(z=18.0));
    height = player.eye_height if isinstance(player, Opponent) else collision.eye_height;
    target = player.pos.sub(Vec3(z=height - 20.0));
    direction = target.sub(origin).normalized();
    finish = origin.add(direction.scale(profile.reach));
    wall = collision.trace_point(origin, finish);
    hit = line_of_fire(world, enemy, person, origin, finish, collision, wall.fraction);
    endpoint = origin.lerp(finish, hit.fraction);
    beam_trail(world, origin, endpoint, profile.beam_kind);
    if hit.actor is not None and amount > 0 {
        strike(hit.actor, amount, enemy, source=origin, tally=tally);
    }
}

def launch_leap(enemy: Opponent, player: Player, profile: AttackProfile) {
    goal = player.pos.sub(enemy.pos);
    goal.z = 0.0;
    if goal.length() < 0.001 {
        goal = forward_from(enemy.yaw, 0.0);
    }
    lift = profile.leap_lift;
    if profile.leap_lift_random > 0.0 {
        enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
        lift += float(enemy.shot_random) / 2147483647.0 * profile.leap_lift_random;
    }
    enemy.pos = enemy.pos.add(Vec3(z=1.0));
    enemy.velocity = goal.normalized().scale(profile.leap_speed).add(Vec3(z=lift));
    enemy.grounded = False;
    enemy.leaping = True;
    enemy.route = [];
}

def event_damage(enemy: Opponent, profile: AttackProfile, index: int) -> int {
    if profile.damages and index < len(profile.damages) {
        return profile.damages[index];
    }
    amount = profile.damage;
    if profile.random_scale > 0.0 {
        total = 0.0;
        for sample in range(3) {
            enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
            total += float(enemy.shot_random) / 2147483647.0;
        }
        return int(total * profile.random_scale);
    }
    if profile.damage_max > amount {
        enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
        amount += enemy.shot_random % (profile.damage_max - amount + 1);
    }
    return amount;
}

# Integrate authored charge distances across 10 Hz animation frames, using the
# same stair/slide collision as walking. Keep a body-width gap to the player.
def attack_charge(enemy: Opponent, player: Player, collision: CollisionMap, dt: float) {
    steps = current_profile(enemy).steps;
    if not enemy.grounded or not steps or dt <= 0.0 or dt > 0.05 {
        return;
    }
    travel = 0.0;
    for frame in range(len(steps)) {
        start = max(enemy.attack_clock, float(frame) * 0.1);
        finish = min(enemy.attack_clock + dt, float(frame + 1) * 0.1);
        travel += max(0.0, finish - start) * 10.0 * steps[frame];
    }
    goal = player.pos.sub(enemy.pos);
    goal.z = 0.0;
    if travel > 0.0 {
        travel = min(travel, max(0.0, goal.length() - 32.0));
    }
    if abs(travel) <= 0.000001 {
        return;
    }
    collision = collision.for_body(enemy.eye_height);
    body = enemy.pos.sub(Vec3(z=enemy.eye_height));
    ahead = body.add(goal.normalized().scale(travel));
    support = collision.trace(ahead.add(Vec3(z=18.0)), ahead.sub(Vec3(z=18.0)));
    if support.fraction == 1.0 or support.normal.z < 0.7 {
        return;
    }
    moved = step_slide(collision, body, goal.normalized().scale(travel / dt), dt, True);
    enemy.pos = moved.pos.add(Vec3(z=enemy.eye_height));
    enemy.velocity.x = 0.0;
    enemy.velocity.y = 0.0;
}

# Attack events run on the simulation clock, independently of the 10 Hz steering query.
def advance_attack_segment(
    world: World,
    enemy: Opponent,
    player: Player,
    collision: CollisionMap,
    dt: float,
    person: Player | None = None,
    tally: CombatState | None = None
) {
    if enemy.attack_clock < 0.0 or enemy.health <= 0 or enemy.dormant {
        return;
    }
    profile = current_profile(enemy);
    attack_charge(enemy, player, collision, dt);
    speaker = profile_speaker(enemy);
    if speaker is not None and dt > 0.0 {
        speaker.origin = enemy.pos.add(Vec3());
        for at in profile.sound_times {
            if (
                enemy.attack_clock + 0.000001 < at
                and enemy.attack_clock + dt + 0.000001 >= at
            )
                or (at == 0.0 and enemy.attack_clock == 0.0) {
                speaker.requests += 1;
            }
        }
    }
    extra = speaker_for(enemy, profile.extra_sound);
    if extra is not None and dt > 0.0 {
        extra.origin = enemy.pos.add(Vec3());
        for at in profile.extra_sound_times {
            if (
                enemy.attack_clock + 0.000001 < at
                and enemy.attack_clock + dt + 0.000001 >= at
            )
                or (at == 0.0 and enemy.attack_clock == 0.0) {
                extra.requests += 1;
            }
        }
    }
    enemy.attack_clock += dt;
    while enemy.attack_event < attack_event_count(enemy)
        and attack_event_time(enemy) <= enemy.attack_clock + 0.000001 {
        enemy.attack_event += 1;
        event_index = enemy.attack_event - 1;
        delta = player.pos.sub(enemy.pos);
        distance = delta.length();
        sight = collision.trace_point(enemy.pos, player.pos);
        if player.health <= 0
            or (
                (not profile.lock_aim or profile.kind == "melee")
                and (
                    sight.start_solid
                    or sight.fraction < 1.0
                    or distance > profile.max_range
                )
            ) {
            continue;
        }
        if profile.kind == "melee" {
            if distance <= profile.reach {
                amount = event_damage(enemy, profile, event_index);
                dealt = strike(player, amount, enemy, source=enemy.pos, tally=tally);
                if dealt > 0 and profile.knockback != 0.0 {
                    player.velocity = player.velocity.add(
                        delta.normalized().scale(profile.knockback)
                    );
                    if player.velocity.z > 0.0 {
                        player.grounded = False;
                    }
                }
            }
        } elif profile.kind == "leap" {
            launch_leap(enemy, player, profile);
        } elif profile.kind == "beam" {
            opponent_beam(
                world,
                enemy,
                player,
                collision,
                profile,
                event_damage(enemy, profile, event_index),
                person,
                tally
            );
        } elif profile.missile_speed > 0.0 {
            direction = opponent_aim(enemy, player, profile);
            if event_index < len(profile.missile_yaw) {
                direction = rotate_yaw(direction, profile.missile_yaw[event_index]);
            }
            count = max(1, profile.missile_count);
            for shot in range(count) {
                aimed = rotate_yaw(
                    direction, (float(shot) - float(count - 1) * 0.5) * 6.0
                )
                    if count > 1
                    else direction;
                velocity = aimed.scale(profile.missile_speed);
                if profile.gravity {
                    velocity.z = 200.0;
                }
                world +>:HasProjectile:+> Projectile(
                    pos=enemy.pos,
                    velocity=velocity,
                    damage=profile.damage,
                    hostile=True,
                    effect=profile.missile_effect,
                    gravity=profile.gravity,
                    splash=profile.splash,
                    radius=profile.radius,
                    homing=profile.homing,
                    homing_wait=0.2 if profile.homing > 0.0 else 0.0,
                    beam_damage=profile.beam_damage,
                    beam_radius=profile.beam_radius,
                    burst_damage=profile.burst_damage,
                    burst_radius=profile.burst_radius,
                    remaining=2.5 if profile.gravity else 5.0,
                    owner=enemy,
                    quarry=player
                );
            }
        } else {
            offset = profile.missile_yaw[event_index]
                if event_index < len(profile.missile_yaw)
                else 0.0;
            opponent_shot(world, enemy, player, collision, profile, offset, person, tally);
        }
    }
    enemy.attack_flash = max(0.0, attack_duration(enemy) - enemy.attack_clock);
    if enemy.attack_clock >= attack_duration(enemy) {
        enemy.attack_clock = -1.0;
    }
}

# Split a tick at the refire boundary so recovery and repeated attack movement
# never run in the same slice. The saved clock/cursor/random stream are sufficient
# to restore a sequence; no hidden per-frame refire flag is needed.
def advance_attack(
    world: World,
    enemy: Opponent,
    player: Player,
    collision: CollisionMap,
    dt: float,
    person: Player | None = None,
    tally: CombatState | None = None
) {
    profile = current_profile(enemy);
    restart = profile.repeat_start;
    boundary = profile.repeat_end;
    chance = profile.repeat_chance;
    if restart < 0.0 or boundary <= restart or boundary >= attack_duration(enemy) {
        advance_attack_segment(world, enemy, player, collision, dt, person, tally);
        return;
    }
    remaining = dt;
    while remaining > 0.000001 and enemy.attack_clock >= 0.0 {
        before = enemy.attack_clock;
        step = remaining;
        crossing = before < boundary - 0.000001
            and before + step >= boundary - 0.000001;
        if crossing {
            step = max(0.0, boundary - before);
        }
        advance_attack_segment(world, enemy, player, collision, step, person, tally);
        remaining = max(0.0, remaining - step);
        if crossing and enemy.attack_clock >= 0.0 and player.health > 0 {
            distance = player.pos.sub(enemy.pos).length();
            sight = collision.trace_point(enemy.pos, player.pos);
            valid = distance <= profile.reach
                if profile.kind == "melee"
                else (
                    distance > melee_reach(enemy)
                    and distance >= profile.min_range
                );
            if valid
                and distance <= profile.max_range
                and not sight.start_solid
                and sight.fraction == 1.0 {
                enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
                if float(enemy.shot_random) / 2147483647.0 < chance {
                    enemy.attack_clock = restart;
                    enemy.attack_event = 0;
                    for at in attack_times(enemy) {
                        if at < restart - 0.000001 {
                            enemy.attack_event += 1;
                        }
                    }
                    # A shot on the first repeated pose happens at the boundary.
                    advance_attack_segment(world, enemy, player, collision, 0.0, person, tally);
                }
            }
        }
    }
}

def pain_pose_time(enemy: Opponent) -> float {
    elapsed = max(0.0, pain_length(enemy) - enemy.pain_wait) * 10.0;
    if enemy.pain_down and enemy.rule.knockdown_hold_frame >= 0 {
        hold_frame = float(enemy.rule.knockdown_hold_frame);
        hold = enemy.rule.knockdown_hold_time * 10.0;
        if elapsed < hold_frame {
            return elapsed;
        }
        if elapsed < hold_frame + hold {
            return hold_frame;
        }
        return elapsed - hold;
    }
    return elapsed;
}

walker CombatTick {
    has player: Player,
        collision: CollisionMap,
        state: CombatState,
        dt: float,
        active: bool = True,
        arena_live: bool = False,
        world: World | None = None,
        body_collision: CollisionMap | None = None,
        navmesh: NavMesh | None = None,
        neighbors: dict[str, list[Opponent]] = {},
        decisions: int = 0;

    def cell(x: int, y: int) -> str { return str(x) + ":" + str(y); }

    def nearby(pos: Vec3) -> list[Opponent] {
        result: list[Opponent] = [];
        x = int(math.floor(pos.x / 64.0));
        y = int(math.floor(pos.y / 64.0));
        for dx in [-1, 0, 1] {
            for dy in [-1, 0, 1] {
                key = self.cell(x + dx, y + dy);
                if key in self.neighbors { result.extend(self.neighbors[key]); }
            }
        }
        return result;
    }

    """Q3 BotFindEnemy: keep a living, visible enemy; otherwise take the
    nearest visible competitor, falling back to the player."""
    def select_foe(bot: Opponent) -> Player {
        current = bot.foe;
        if current is not None and current.health > 0 {
            dormant = isinstance(current, Opponent) and current.dormant;
            if not dormant {
                sight = self.collision.trace_point(bot.pos, current.pos);
                if bot.alert > 0.0 or (not sight.start_solid and sight.fraction == 1.0) {
                    return current;
                }
            }
        }
        candidates: list[Player] = [];
        if self.player.health > 0 {
            candidates.append(self.player);
        }
        if self.world is not None {
            for other in [self.world->:HasOpponent:->][?:Opponent] {
                if other is not bot and other.arena and other.health > 0 and not other.dormant {
                    candidates.append(other);
                }
            }
        }
        # ai_dmq3.c BotFindEnemy: alert characters see further, and a new
        # enemy must be inside a 90 degree view unless it is close or firing.
        mind = bot.character;
        reach = 900.0 + mind.alertness * 4000.0 if mind is not None else 1500.0;
        best: Player = self.player;
        best_distance = 100000.0;
        for candidate in candidates {
            distance = candidate.pos.sub(bot.pos).length();
            if distance >= best_distance or distance > reach {
                continue;
            }
            if mind is not None and distance > 100.0 {
                firing = candidate.attack_flash > 0.0
                    if isinstance(candidate, Opponent)
                    else self.state.flash > 0.0;
                toward = candidate.pos.sub(bot.pos);
                bearing = math.atan2(toward.y, toward.x);
                off = abs(math.atan2(math.sin(bearing - bot.yaw), math.cos(bearing - bot.yaw)));
                if not firing and off > math.pi / 4.0 {
                    continue;
                }
            }
            sight = self.collision.trace_point(bot.pos, candidate.pos);
            if sight.start_solid or sight.fraction < 1.0 {
                continue;
            }
            best = candidate;
            best_distance = distance;
        }
        bot.foe = best if best_distance < 100000.0 else None;
        return best;
    }

    can begin with World entry {
        self.world = here;
        # The level's AAS mesh, looked up once per level.
        if not self.state.navmesh_checked {
            self.state.navmesh_checked = True;
            meshes = [here->:HasNavMesh:->][?:NavMesh];
            if meshes {
                self.state.navmesh = meshes[0];
            }
        }
        self.navmesh = self.state.navmesh;
        for enemy in [here->:HasOpponent:->][?:Opponent] {
            if enemy.health <= 0 or enemy.dormant or enemy.alert <= 0.0 {
                if enemy.route_search is not None {
                    enemy.route_search.cancelled = True;
                    enemy.route_search = None;
                }
                if enemy.health <= 0 or enemy.dormant { continue; }
            }
            key = self.cell(int(math.floor(enemy.pos.x / 64.0)), int(math.floor(enemy.pos.y / 64.0)));
            if key not in self.neighbors { self.neighbors[key] = []; }
            self.neighbors[key].append(enemy);
        }
        self.state.route_credit = min(
            1.0, self.state.route_credit + max(0.0, self.dt) * 8.0
        );
        self.state.navigation.network.refresh(self.collision);
        # Arena matches keep running while the player waits to respawn.
        live = self.player.health > 0 or self.arena_live;
        if self.active and live { self.state.navigation.advance(); }
        here spawn ParticleTick(dt=self.dt);
        self.state.cooldown = max(0.0, self.state.cooldown - self.dt);
        self.state.noise = max(0.0, self.state.noise - self.dt);
        self.state.sight_wait = max(0.0, self.state.sight_wait - self.dt);
        self.state.flash = max(0.0, self.state.flash - self.dt);
        self.state.hit_flash = max(0.0, self.state.hit_flash - self.dt);
        if self.active and live {
            visit [here->:HasOpponent:->];
        }
    }

    can think with Opponent entry {
        if here.rule.script {
            return;
        }
        # Inert targets (exploding barrels) only wait to be destroyed.
        if here.rule.inert {
            if here.pending_explosion and self.world is not None {
                death_explosion(self.world, here, self.player, self.collision, self.state);
            }
            return;
        }
        ensure_profiles(here);
        if here.rule.decoration {
            if here.activation.pending > 0 {
                # Targeted static figures leave the scene, as the original teleport-away bodies do.
                here.activation.pending = 0;
                here.visual.visible = False;
            }
            if here.idle_animation {
                here.animation_time += self.dt * 4.0;
                index = int(here.animation_time) % len(here.idle_animation);
                here.visual.first = here.idle_animation[index];
                here.visual.second = here.idle_animation[
                    (index + 1) % len(here.idle_animation)
                ];
                here.visual.blend = here.animation_time - float(int(here.animation_time));
            }
            return;
        }
        if here.health > 0 and here.activation.pending > 0 {
            here.activation.pending = 0;
            if here.dormant and here.spawn_wait < 0.0 {
                here.spawn_wait = 0.1;
            }
            here.last_seen = self.player.pos;
            here.last_seen_height = self.collision.eye_height;
            here.alert = 8.0;
            here.decision_wait = 0.0;
        }
        if here.dormant {
            if here.spawn_wait < 0.0 {
                return;
            }
            here.spawn_wait = max(0.0, here.spawn_wait - self.dt);
            if here.spawn_wait > 0.0 {
                return;
            }
            here.dormant = False;
            here.pos = here.pos.add(Vec3(z=1.0));
            here.visual.visible = here.health > 0;
            separation = here.pos.sub(self.player.pos);
            if abs(separation.x) < 32.0
                and abs(separation.y) < 32.0
                and abs(separation.z) < 56.0 {
                self.player spawn Damage(
                    amount=100000, bypass_armor=True, bypass_protection=True
                );
            }
        }
        if self.body_collision is None
            or self.body_collision.eye_height != here.eye_height {
            self.body_collision = self.collision.for_body(here.eye_height);
        }
        body_collision = self.body_collision;
        if here.pending_explosion and self.world is not None {
            death_explosion(self.world, here, self.player, self.collision, self.state);
        }
        if here.health <= 0 {
            # Q3 players drop their weapon when they die.
            dropped = here.weapon_visual;
            if dropped is not None {
                dropped.visible = False;
            }
            gibs = here.gib_rule;
            if here.pending_gibs >= 0 and gibs is not None and self.world is not None {
                throw_gibs(
                    self.world,
                    here,
                    gibs,
                    here.pos.sub(Vec3(z=here.eye_height)),
                    here.pending_gibs,
                    here.shot_random,
                    here.velocity
                );
            }
            here.pending_gibs = -1;
            if here.death_animation {
                here.animation_time += self.dt * 10.0;
                index = min(int(here.animation_time), len(here.death_animation) - 1);
                here.visual.first = here.death_animation[index];
                here.visual.second = here.death_animation[
                    min(index + 1, len(here.death_animation) - 1)
                ];
                here.visual.blend = here.animation_time
                    - float(int(here.animation_time));
            }
            if here.rule.movement == "fly" and not here.grounded {
                here spawn MovePlayer(collision=body_collision, wish=Vec3(), dt=self.dt);
            }
            successor = here.successor;
            if successor is not None
                and successor.dormant
                and successor.spawn_wait < 0.0
                and here.animation_time >= float(len(here.death_animation)) - 1.0 {
                # The mech's pilot bursts out toward the player once the wreck settles.
                successor.spawn_wait = 0.8;
                successor.pos = here.pos.add(Vec3());
                successor.home = here.pos.add(Vec3());
                toward = self.player.pos.sub(here.pos);
                toward.z = 0.0;
                successor.velocity = toward.normalized().scale(400.0).add(Vec3(z=200.0));
                successor.yaw = math.atan2(toward.y, toward.x);
                successor.last_seen = self.player.pos;
                successor.last_seen_height = self.collision.eye_height;
                successor.alert = 8.0;
            }
            if not here.arena {
                return;
            }
            here.respawn_wait = max(0.0, here.respawn_wait - self.dt);
            if here.respawn_wait > 0.0 {
                return;
            }
            destination = here.home;
            spawn_yaw = here.yaw;
            if self.world is not None {
                avoid = [self.player.pos];
                for other in [self.world->:HasOpponent:->][?:Opponent] {
                    if other is not here and other.health > 0 {
                        avoid.append(other.pos);
                    }
                }
                here.shot_random = (here.shot_random * 48271) % 2147483647;
                choice = self.world spawn ChooseSpawn(avoid=avoid, seed=here.shot_random);
                spot = choice.pick();
                if spot is not None {
                    destination = spot.pos.add(Vec3(z=here.eye_height + 1.0));
                    spawn_yaw = spot.yaw;
                }
            }
            if destination.sub(self.player.pos).length() < 80.0 {
                return;
            }
            # g_client.c ClientSpawn: 25 over maximum, empty armor and inventory.
            here.health = here.max_health + 25;
            here.armor = 0;
            here.inventory = Inventory();
            if here.character is not None {
                arm_bot(here);
            }
            here.gibbed = False;
            here.remains = 0;
            here.foe = None;
            here.alert = 0.0;
            here.yaw = spawn_yaw;
            here.pose_name = "";
            here.pos = destination;
            here.route = [];
            here.route_areas = [];
            here.route_wait = 0.0;
            here.velocity = Vec3();
            here.visual.visible = True;
            here.attack_wait = 1.0;
            here.attack_profile = -1;
            here.leaping = False;
            here.pain_down = False;
            here.pain_wait = 0.0;
        }
        # Arena bots fight every competitor; campaign monsters hunt the player
        # unless infighting has turned them on another monster (ai.qc ai_run
        # returns to the old enemy once that one dies).
        foe: Player = self.player;
        if here.arena {
            foe = self.select_foe(here);
        } elif here.foe is not None {
            rival = here.foe;
            if rival.health > 0 and not (isinstance(rival, Opponent) and rival.dormant) {
                foe = rival;
            } else {
                here.foe = None;
                if here.resume_hunt {
                    here.last_seen = self.player.pos.add(Vec3());
                    here.last_seen_height = self.collision.eye_height;
                    here.alert = 8.0;
                } else {
                    here.alert = 0.0;
                }
                here.resume_hunt = False;
            }
        }
        # An alerted monster leaves its patrol unless it is bound for a combat point.
        if here.alert > 0.0 and not here.holding {
            here.patrol_goal = None;
        }
        foe_height = foe.eye_height
            if isinstance(foe, Opponent)
            else self.collision.eye_height;
        delta = foe.pos.sub(here.pos);
        distance = delta.length();
        here.pain_wait = max(0.0, here.pain_wait - self.dt);
        if here.pain_wait <= 0.0 and here.pain_down {
            here.pain_down = False;
            here.pain_variant = 0;
        }
        here.pain_cooldown = max(0.0, here.pain_cooldown - self.dt);
        here.attack_wait = max(0.0, here.attack_wait - self.dt);
        here.attack_flash = max(0.0, here.attack_flash - self.dt);
        here.alert = max(0.0, here.alert - self.dt);
        here.route_wait = max(0.0, here.route_wait - self.dt);
        here.decision_wait -= self.dt;
        if here.decision_wait <= 0.0 and self.decisions < 8 {
            self.decisions += 1;
            here.decision_wait = 0.1;
            here.pursuing = False;
            was_alert = here.alert > 0.0;
            if distance < 1500.0 {
                sight = self.collision.trace_point(here.pos, foe.pos);
                here.pursuing = not sight.start_solid and sight.fraction == 1.0;
                if here.pursuing and not was_alert and not here.arena {
                    here.pursuing = notices(here, foe.pos, distance, self.state.noise > 0.0);
                }
                if not here.pursuing and not was_alert and not here.arena and not here.ambush {
                    # Q2 PlayerNoise: gunfire is heard within 1000 units.
                    if here.game == "q2" and self.state.noise > 0.0 and distance < 1000.0 {
                        here.last_seen = foe.pos;
                        here.last_seen_height = foe_height;
                        here.alert = 8.0;
                    }
                    # Q1 sight_entity / Q2 sight_client: a monster that has just
                    # spotted the player wakes others that can see it.
                    sighter = self.state.sighter;
                    if sighter is not None
                        and self.state.sight_wait > 0.0
                        and sighter is not here {
                        gap = sighter.pos.sub(here.pos).length();
                        glimpse = self.collision.trace_point(here.pos, sighter.pos);
                        if not glimpse.start_solid
                            and glimpse.fraction == 1.0
                            and notices(here, sighter.pos, gap, False) {
                            here.last_seen = foe.pos;
                            here.last_seen_height = foe_height;
                            here.alert = 8.0;
                        }
                    }
                }
                # Q1 ai.qc FindTarget / Q3 BotFindEnemy: invisible players are
                # not newly noticed, though Q3 bots still spot muzzle flashes.
                if here.pursuing
                    and not was_alert
                    and empowered(foe, "invisibility")
                    and not (here.arena and foe is self.player and self.state.flash > 0.0) {
                    here.pursuing = False;
                }
                if here.pursuing {
                    here.last_seen = foe.pos;
                    here.last_seen_height = foe_height;
                    here.alert = 8.0;
                    if not was_alert and not here.sighted {
                        request_sound(here, here.rule.sight_sound);
                        if not here.arena {
                            self.state.sighter = here;
                            self.state.sight_wait = 0.1;
                        }
                    }
                    here.sighted = True;
                }
                # Attack only with a fresh sight query, never cached visibility.
                if here.pursuing
                    and not here.holding
                    and here.character is None
                    and here.attack_wait <= 0.0
                    and here.pain_wait <= 0.0
                    and here.attack_clock < 0.0
                    and not here.leaping {
                    selected = choose_attack(here, distance);
                    if selected >= 0 {
                        select_profile(here, selected);
                        profile = here.profiles[selected];
                        here.attack_target = foe.pos.add(Vec3());
                        here.attack_clock = 0.0;
                        here.attack_event = 0;
                        here.burst_count = 1;
                        if profile.burst_max > 1 and not here.attack_melee {
                            here.shot_random = (here.shot_random * 48271) % 2147483647;
                            here.burst_count = profile.burst_min
                                + here.shot_random
                                    % (profile.burst_max - profile.burst_min + 1);
                        }
                        here.attack_wait = max(
                            attack_pause(here), attack_duration(here)
                        );
                        here.attack_flash = attack_duration(here);
                    }
                }
            }
            if here.alert <= 0.0 and not here.pursuing {
                here.sighted = False;
            }
            # A fighting bot steers itself (BotTactics); others steer here.
            if not here.fighting {
                here.steering = Vec3();
            }
            destination = here.arena_goal if here.arena_goal is not None else here.last_seen;
            # Arena goals sit at the bot's own eye height above the item.
            goal_height = here.eye_height if here.arena_goal is not None else here.last_seen_height;
            # Patrol corners and Q2 combat points take precedence over the foe.
            patrol = here.patrol_goal;
            if patrol is not None {
                destination = patrol;
                goal_height = here.eye_height;
            }
            if here.grounded
                and here.alert > 0.0
                and here.attack_clock < 0.0
                and here.rule.movement == "walk" {
                origin = here.pos.sub(Vec3(z=here.eye_height));
                target = destination.sub(Vec3(z=goal_height));
                if here.route_search is not None {
                    if here.route_search.finish.sub(target).length() > 48.0 {
                        here.route_search.cancelled = True;
                        here.route_search = None;
                    } elif here.route_search.done {
                        here.route = here.route_search.result;
                        here.route_launches = here.route_search.launches;
                        here.route_areas = [];
                        here.route_search = None;
                        here.navigation_needed = False;
                    }
                }
                if here.route_target.sub(target).length() > 48.0 {
                    here.route = [];
                    here.route_areas = [];
                }
                # AAS routes are followed every tick below; local routes here.
                while here.route
                    and len(here.route_areas) != len(here.route)
                    and waypoint_reached(here.route[0], origin, False) {
                    if here.route_launches and here.route_launches[0].z > 0.0 {
                        here.velocity = here.route_launches[0];
                        here.grounded = False;
                    }
                    here.route.pop(0);
                    if here.route_launches { here.route_launches.pop(0); }
                    if not here.grounded { break; }
                }
                wants_route = not here.route
                    and here.route_search is None
                    and (here.arena_goal is not None or not here.pursuing or here.navigation_needed)
                    and here.route_wait <= 0.0;
                mesh = self.navmesh;
                if wants_route and here.arena and mesh is not None {
                    # Q3 bots route over the map's AAS, the original bots' own data.
                    plan = plan_route(mesh, origin, target);
                    here.route_wait = 0.25 if plan.found else 1.0;
                    here.route_target = target;
                    # botlib avoids goals it cannot route to; pick another.
                    if not plan.found and here.arena_goal is not None {
                        here.roam_goal = None;
                        here.arena_goal = None;
                        here.arena_goal_wait = 0.0;
                        here.route_wait = 0.1;
                    }
                    if plan.found {
                        here.route = plan.points;
                        here.route_launches = plan.launches;
                        here.route_areas = plan.areas;
                        here.navigation_needed = False;
                    }
                } elif wants_route
                    and len(self.state.navigation.jobs) < 8
                    and self.state.route_credit >= 1.0 {
                    self.state.route_credit -= 1.0;
                    here.route_wait = 1.0;
                    here.route_target = target;
                    here.route_areas = [];
                    if here.route_search is None {
                        here.route_search = RouteSearch(start=origin, finish=target, collision=body_collision, network=self.state.navigation.network, allow_jumps=here.arena);
                        self.state.navigation.jobs.append(here.route_search);
                    }
                }
                if here.route {
                    destination = here.route[0].add(Vec3(z=here.eye_height));
                }
            }
            goal = destination.sub(here.pos);
            if (here.alert > 0.0 or patrol is not None)
                and not here.fighting
                and here.pain_wait <= 0.0
                and here.attack_flash <= 0.0
                and not here.leaping
                and here.rule.movement != "none"
                and goal.length()
                    > (
                        here.rule.stop_range
                            if here.pursuing
                                and here.arena_goal is None
                                and patrol is None
                                and len(here.route) <= 1
                            else 12.0
                    ) {
                direction = Vec3(x=goal.x, y=goal.y).normalized();
                # Local separation is evaluated with steering, not every physics tick.
                if self.world is not None {
                    for neighbor in self.nearby(here.pos) {
                        if neighbor == here
                            or neighbor.health <= 0
                            or neighbor.dormant {
                            continue;
                        }
                        away = here.pos.sub(neighbor.pos);
                        if abs(away.z) < 56.0 {
                            away.z = 0.0;
                            spacing = away.length();
                            if spacing > 0.001 and spacing < 56.0 {
                                direction = direction.add(
                                    away.scale((56.0 - spacing) / (56.0 * spacing))
                                );
                            }
                        }
                    }
                    direction = direction.normalized();
                }
                # AAS legs are known passable (drops, jumps and pads included);
                # a floor probe would reject some, so the bot heads straight on.
                trusted_leg = bool(here.route) and len(here.route_areas) == len(here.route);
                best = -1.0;
                for angle in ([0.0] if trusted_leg else [0.0, 0.785398, -0.785398, 1.570796, -1.570796]) {
                    candidate = Vec3(
                        x=direction.x * math.cos(angle) - direction.y * math.sin(angle),
                        y=direction.x * math.sin(angle) + direction.y * math.cos(angle)
                    );
                    probe = Trace();
                    if here.grounded and here.rule.movement == "walk" and not trusted_leg {
                        origin = here.pos.sub(Vec3(z=here.eye_height));
                        reachable = walk_edge(
                            body_collision,
                            origin,
                            origin.add(candidate.scale(48.0)),
                            match_height=False
                        );
                        if reachable is None {
                            # A blocked local route is searched again; an AAS
                            # route is authoritative, so only this heading fails.
                            if angle == 0.0 and len(here.route_areas) != len(here.route) {
                                here.route = [];
                                here.route_launches = [];
                                here.navigation_needed = True;
                            }
                            continue;
                        }
                    } else {
                        origin = here.pos.sub(Vec3(z=here.eye_height));
                        probe = body_collision.trace(origin, origin.add(candidate.scale(48.0)));
                    }
                    score = probe.fraction + 0.15 * math.cos(angle);
                    if not probe.start_solid
                        and probe.fraction > 0.3
                        and score > best {
                        best = score;
                        here.steering = candidate;
                        # Candidates are ordered by descending directional score.
                        if probe.fraction == 1.0 { break; }
                    }
                }
            }
        }
        # Bots steer every frame: an AAS waypoint is done on reaching it or on
        # entering its target area, and takeoffs launch from the ground.
        mesh = self.navmesh;
        if here.arena
            and mesh is not None
            and not here.fighting
            and here.route
            and len(here.route_areas) == len(here.route)
            and here.attack_clock < 0.0 {
            standing_origin = here.pos.sub(Vec3(z=here.eye_height));
            standing = mesh.locate(standing_origin);
            while here.route {
                done = waypoint_reached(here.route[0], standing_origin, True)
                    or (here.route_areas[0] > 0 and standing == here.route_areas[0]);
                if not done {
                    break;
                }
                if here.route_launches and here.route_launches[0].z > 0.0 {
                    if not here.grounded {
                        break;
                    }
                    here.velocity = here.route_launches[0];
                    here.grounded = False;
                }
                here.route.pop(0);
                here.route_areas.pop(0);
                if here.route_launches {
                    here.route_launches.pop(0);
                }
            }
            if here.route {
                ahead = here.route[0].sub(standing_origin);
                ahead.z = 0.0;
                if ahead.length() > 0.001 {
                    here.steering = ahead.normalized();
                }
            }
        }
        if self.world is not None and here.character is None {
            advance_attack(
                self.world, here, foe, self.collision, self.dt, self.player, self.state
            );
        }
        # Idle patrols walk at the original walk-cycle pace; anything else runs.
        strolling = here.patrol_goal is not None and here.alert <= 0.0;
        here.walk_speed = here.rule.speed;
        if strolling {
            here.walk_speed = here.patrol_speed
                if here.patrol_speed > 0.0
                else here.rule.speed * 0.4;
        }
        # Bots keep steering over stair steps and drops, but not while a jump or
        # pad launch is still carrying them upward.
        wish = Vec3()
            if here.pain_wait > 0.0
                or (here.attack_flash > 0.0 and here.character is None)
                or here.leaping
                or (here.arena and not here.grounded and here.velocity.z > 100.0)
            else here.steering;
        facing = here.patrol_goal;
        if facing is None and here.alert > 0.0 {
            facing = here.last_seen;
        }
        if facing is not None and not here.fighting {
            goal = facing.sub(here.pos);
            target_yaw = math.atan2(goal.y, goal.x);
            turn = math.atan2(
                math.sin(target_yaw - here.yaw), math.cos(target_yaw - here.yaw)
            );
            here.yaw += max(-6.0 * self.dt, min(6.0 * self.dt, turn));
        }
        if here.rule.movement == "walk" or here.rule.movement == "none" {
            if here.rule.movement == "none" {
                here.velocity = Vec3();
            } else {
                here.support_wait -= self.dt;
                # Settled actors probe support at 20 Hz; motion and gravity remain 120 Hz.
                if not here.grounded
                    or here.velocity.length() > 0.000001
                    or wish.length() > 0.0
                    or here.support_wait <= 0.0 {
                    here spawn MovePlayer(
                        collision=body_collision,
                        wish=wish,
                        dt=self.dt,
                        steady=strolling
                    );
                    here.support_wait = 0.05;
                }
            }
        } elif here.rule.movement == "swim" and here.water_depth < 2 {
            here spawn MovePlayer(collision=body_collision, wish=Vec3(), dt=self.dt);
        } elif self.dt > 0.0 and self.dt <= 0.05 {
            # Fliers and swimmers hold 30 to 40 units above the target origin.
            desired = Vec3();
            if wish.length() > 0.0 {
                desired = Vec3(x=wish.x, y=wish.y);
                corner = here.patrol_goal;
                if corner is not None {
                    # Fly straight at a path corner.
                    rise = here.pos.z - corner.z;
                    if rise > 8.0 {
                        desired.z = -1.0;
                    } elif rise < -8.0 {
                        desired.z = 1.0;
                    }
                } else {
                    rise = (here.pos.z - here.eye_height)
                        - (here.last_seen.z - here.last_seen_height);
                    if rise > 40.0 {
                        desired.z = -1.0;
                    } elif rise < 30.0 {
                        desired.z = 1.0;
                    }
                }
                desired = desired.normalized().scale(here.walk_speed * speed_scale(here));
            }
            here.velocity = here.velocity.add(
                desired.sub(here.velocity).scale(min(1.0, 8.0 * self.dt))
            );
            body = here.pos.sub(Vec3(z=here.eye_height));
            moved = slide(body_collision, body, here.velocity, self.dt);
            here.velocity = moved.velocity;
            here.pos = moved.pos.add(Vec3(z=here.eye_height));
            here.grounded = False;
        }
        if here.leaping {
            if here.grounded {
                here.leaping = False;
            } elif here.velocity.length() > 400.0 and foe.health > 0 {
                contact = foe.pos.sub(here.pos);
                if abs(contact.x) < here.rule.width + 16.0
                    and abs(contact.y) < here.rule.width + 16.0
                    and abs(contact.z) < 56.0 {
                    profile = current_profile(here);
                    amount = event_damage(here, profile, 0);
                    dealt = strike(foe, amount, here, source=here.pos, tally=self.state);
                    if dealt > 0 {
                        push = Vec3(x=contact.x, y=contact.y).normalized();
                        foe.velocity = foe.velocity.add(
                            push.scale(float(amount) * 8.0)
                        );
                    }
                    here.leaping = False;
                }
            }
        }
        pose_name = "attack"
            if here.attack_flash > 0.0
            else ("run" if wish.length() > 0.0 else "stand");
        if here.pain_wait > 0.0 {
            pose_name = "pain";
        }
        # Idle patrols use the walk cycle (Q1 prowl/walk, Q2 walk) at 10 Hz.
        if pose_name == "run" and here.alert <= 0.0 and here.walk_animation {
            pose_name = "walk";
        }
        frames = here.animation if pose_name == "run" else here.idle_animation;
        if pose_name == "walk" {
            frames = here.walk_animation;
        }
        if pose_name == "attack" {
            frames = profile_frames(here, here.attack_profile);
        }
        if pose_name == "pain" {
            frames = here.pain_animation;
            if here.pain_down and here.knockdown_animation {
                frames = here.knockdown_animation;
            } elif here.pain_variant > 0
                and here.pain_variant - 1 < len(here.pain_animations)
                and here.pain_animations[here.pain_variant - 1] {
                frames = here.pain_animations[here.pain_variant - 1];
            }
        }
        if not frames {
            frames = here.animation;
        }
        if pose_name != here.pose_name {
            here.animation_time = 0.0;
            here.pose_name = pose_name;
        }
        if frames {
            if pose_name == "attack" and here.attack_clock >= 0.0 {
                here.animation_time = attack_pose_time(here);
            } elif pose_name == "pain" {
                here.animation_time = pain_pose_time(here);
            } else {
                here.animation_time += self.dt * (
                    10.0 if pose_name == "walk" else (8.0 if pose_name != "stand" else 2.0)
                );
            }
            index = int(here.animation_time) % len(frames);
            if pose_name in ["attack", "pain"] {
                index = min(int(here.animation_time), len(frames) - 1);
            }
            here.visual.first = frames[index];
            here.visual.second = frames[min(index + 1, len(frames) - 1)]
                if pose_name in ["attack", "pain"]
                else frames[(index + 1) % len(frames)];
            here.visual.blend = here.animation_time - float(int(here.animation_time));
        }
        # A bot's held weapon is baked along its body's poses, frame for frame.
        held = here.weapon_visual;
        if held is not None {
            held.first = here.visual.first;
            held.second = here.visual.second;
            held.blend = here.visual.blend;
            held.visible = here.visual.visible;
        }
    }
}
