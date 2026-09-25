"""Shared weapon simulation and graph-driven opponents."""
import math;
import from .particles {
    impact_spray,
    ParticleTick,
    rail_trail,
    beam_trail,
    explode,
    blast_kind
}
import from .navigation { RouteSearch, RouteQueue, walk_edge }
import from .opponent_rule { OpponentRule, AttackProfile, rule_profiles }
import from .weapons { WeaponRule }
import from .world { World, Player, area_of, move_to_area }
import from .damage { Damage, blast_strength }
import from .powerups { damage_scale, fire_interval_scale, empowered, speed_scale }
import from .arena { ChooseSpawn }
import from .inventory { Inventory, quantity, AdjustInventory }
import from .models { Visual, ModelResource, UsesModel, PlayerRig }
import from .player_rig { PoseRig, rig_sound, reset_rig }
import from .body_queue { CorpseTick, leave_corpse }
import from .drops { toss_items }
import from .gibs { GibRule, gibs_at, throw_gibs }
import from .bot_routes { NavMesh, HasNavMesh, plan_route }
import from .bot_character { BotCharacter, BotState }
import from .trail { next_crumb, trail_clock }
import from .speakers { Speaker }
import from .signals { Signal, HasSignal, Fire }
import from .pickups { Pickup }
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
        duck_animation: list[int] = [],
        knockdown_animation: list[int] = [],
        death_animation: list[int] = [],
        profiles: list[AttackProfile] = [],
        pain_wait: float = 0.0,
        duck_wait: float = 0.0,
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
        bot_state: BotState = BotState(),
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
        shown_weapon: str = "",
        trail_stamp: float = 0.0,
        slide_wait: float = 0.0,
        lefty: bool = False,
        idle_wait: float = -1.0,
        tend_wait: float = 0.0,
        revived: bool = False,
        power_cells: int = -1,
        wounded: bool = False,
        healthy_skin: ModelResource | None = None,
        heard: bool = True,
        foe_wait: float = -1.0;
}

"""How far the player's box (at origin `body`) reaches into an actor's box,
horizontally, or None when they do not overlap. Living monsters and bots are
solid to the player (SOLID_SLIDEBOX); corpses are not."""
def actor_overlap(body: Vec3, top_drop: float, actor: Opponent) -> Vec3 | None {
    if actor.health <= 0
        or actor.dormant
        or actor.rule.decoration
        or actor.rule.script
        or not actor.visual.visible {
        return None;
    }
    return box_overlap(
        body,
        top_drop,
        actor.pos.sub(Vec3(z=actor.eye_height)),
        actor.rule.width,
        actor.rule.hull_bottom,
        actor.rule.hull_top
    );
}

def box_overlap(
    body: Vec3, top_drop: float, origin: Vec3, width: float, bottom: float, top: float
) -> Vec3 | None {
    if body.z - 24.0 >= origin.z + top or body.z + 32.0 - top_drop <= origin.z + bottom {
        return None;
    }
    reach = 16.0 + width;
    apart = body.sub(origin);
    if abs(apart.x) >= reach or abs(apart.y) >= reach {
        return None;
    }
    # Leave along the shallower side.
    depth_x = reach - abs(apart.x);
    depth_y = reach - abs(apart.y);
    if depth_x < depth_y {
        return Vec3(x=depth_x if apart.x >= 0.0 else -depth_x);
    }
    return Vec3(y=depth_y if apart.y >= 0.0 else -depth_y);
}

"""Push the player back out of any living monster or bot it walked into,
and stop its motion into that body, so actors block the player."""
walker ClearActors {
    has player: Player,
        collision: CollisionMap;

    can begin with World entry {
        if self.player.health > 0 {
            visit [here->:HasOpponent:->];
        }
    }

    can shove with Opponent entry {
        body = self.player.pos.sub(Vec3(z=self.collision.eye_height));
        push = actor_overlap(body, self.collision.top_drop, here);
        if push is None {
            return;
        }
        moved = self.collision.trace(body, body.add(push));
        if moved.start_solid or moved.fraction < 1.0 {
            return;
        }
        self.player.pos = self.player.pos.add(push);
        if push.x != 0.0 and self.player.velocity.x * push.x < 0.0 {
            self.player.velocity.x = 0.0;
        }
        if push.y != 0.0 and self.player.velocity.y * push.y < 0.0 {
            self.player.velocity.y = 0.0;
        }
    }
}

"""A Q2 monster's bloodied skin, shown once it falls below half health."""
edge Bloodied: Opponent --> ModelResource {}

"""Swap a monster's model skin between healthy and bloodied (Q2 skinnum |= 1)."""
def show_wounds(enemy: Opponent, wounded: bool) {
    if enemy.wounded == wounded {
        return;
    }
    hurt = [enemy->:Bloodied:->][?:ModelResource];
    if not hurt {
        return;
    }
    shown = [enemy.visual->:UsesModel:->][?:ModelResource];
    if not shown {
        return;
    }
    if wounded {
        enemy.healthy_skin = shown[0];
        enemy.visual del --> shown[0];
        enemy.visual +>:UsesModel:+> hurt[0];
    } else {
        healthy = enemy.healthy_skin;
        if healthy is None {
            return;
        }
        enemy.visual del --> shown[0];
        enemy.visual +>:UsesModel:+> healthy;
    }
    enemy.wounded = wounded;
}

"""The item a monster leaves where it dies (Q1 backpacks, Q2 `item`)."""
edge Drops: Opponent --> Pickup {}

"""A Q2 medic's claim on the corpse it is going to raise (AI_MEDIC with the
corpse as its enemy and the corpse's owner set to the medic)."""
edge Mends: Opponent --> Opponent {}

"""Q2 m_medic.c medic_FindDeadMonster: the healthiest-born corpse within 1024
units the medic can see, that has finished dying and nobody else is raising."""
walker FindPatient {
    has medic: Opponent,
        collision: CollisionMap,
        best: Opponent | None = None;

    can begin with World entry {
        visit [here->:HasOpponent:->];
    }

    can consider with Opponent entry {
        if here is self.medic
            or here.health > 0
            or here.gibbed
            or here.dormant
            or here.arena
            or not here.visual.visible
            or not here.death_animation
            or here.rule.inert
            or here.rule.decoration
            or here.rule.passive
            or here.rule.script
            or here.rule.successor
            or here.kind in ["monster_supertank", "monster_boss2", "monster_jorg", "monster_makron", "misc_insane"] {
            return;
        }
        if here.animation_time < float(len(here.death_animation)) - 1.0 {
            return;
        }
        for claimant in [here<-:Mends:<-][?:Opponent] {
            if claimant.health > 0 {
                return;
            }
        }
        if here.pos.sub(self.medic.pos).length() > 1024.0 {
            return;
        }
        sight = self.collision.trace_point(self.medic.pos, here.pos);
        if sight.start_solid or sight.fraction < 1.0 {
            return;
        }
        best = self.best;
        if best is None or here.rule.health > best.rule.health {
            self.best = here;
        }
    }
}

"""m_medic.c medic_cable_attack: stand the corpse back up as a fresh monster
(ED_CallSpawn with its targets cleared) hunting the medic's old enemy."""
def raise_patient(patient: Opponent, medic: Opponent, hunted: Player | None) {
    patient.health = patient.rule.health;
    patient.revived = True;
    show_wounds(patient, False);
    patient.visual.visible = True;
    patient.pose_name = "";
    patient.animation_time = 0.0;
    patient.attack_clock = -1.0;
    patient.attack_flash = 0.0;
    patient.attack_wait = 1.0;
    patient.attack_profile = -1;
    patient.pain_wait = 0.0;
    patient.pain_down = False;
    patient.duck_wait = 0.0;
    patient.leaping = False;
    patient.remains = 0;
    patient.pending_gibs = -1;
    patient.pending_explosion = False;
    patient.route = [];
    patient.route_areas = [];
    patient.foe = None;
    patient.patrol_goal = None;
    patient.holding = False;
    patient.velocity = Vec3();
    if hunted is not None and hunted.health > 0 {
        patient.last_seen = hunted.pos.add(Vec3());
        patient.alert = 8.0;
        patient.sighted = True;
        medic.last_seen = hunted.pos.add(Vec3());
        medic.alert = 8.0;
    }
    medic del --> patient;
}

"""One event of the medic's cable: within 256 units and in sight the cable
reaches the corpse, and at the profile's raise time the corpse stands up."""
def cable_event(
    world: World,
    medic: Opponent,
    patient: Opponent,
    profile: AttackProfile,
    at: float,
    collision: CollisionMap,
    hunted: Player | None
) {
    if patient.health > 0 or patient.gibbed {
        return;
    }
    body = patient.pos.sub(Vec3(z=patient.eye_height * 0.5));
    sight = collision.trace_point(medic.pos, body);
    if body.sub(medic.pos).length() > 256.0 or sight.start_solid or sight.fraction < 1.0 {
        return;
    }
    beam_trail(world, medic.pos.add(forward_from(medic.yaw, 0.0).scale(16.0)), body, "drain");
    if abs(at - profile.revive_at) < 0.001 {
        raise_patient(patient, medic, hunted);
    }
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

"""The wait after an attack before the next may start (attack_finished).
Q1 SUB_AttackFinished and Q2 M_CheckAttack wait a random time after a ranged
attack (0-2 seconds unless the monster sets its own), and none after melee;
Q1 Nightmare skips the wait."""
def attack_pause(enemy: Opponent, melee: bool = False) -> float {
    if melee or (enemy.game == "q1" and enemy.skill >= 3) {
        return 0.0;
    }
    # Drawn beside the monster's stream (another multiplier) rather than from
    # it, so the attack sequence's own choices keep their order.
    roll = float((enemy.shot_random * 16807) % 2147483647) / 2147483647.0;
    return enemy.rule.rest_min + enemy.rule.rest_random * roll;
}

"""Q1 fight.qc CheckAttack and Q2 g_ai.c M_CheckAttack: each 10 Hz decision
a monster in range only starts an attack with a chance that falls with range
class, so between attacks it keeps running at its target. Melee reach always
attacks (Q2 Easy: one time in four). Q2 scales the chance by skill, and
monsters standing their ground fire more often."""
def attack_chance(enemy: Opponent, distance: float, melee: bool) -> float {
    rule = enemy.rule;
    if enemy.game == "q2" {
        if melee {
            return 0.25 if enemy.skill <= 0 else 1.0;
        }
        chance = 0.0;
        if enemy.holding or rule.movement == "none" {
            chance = 0.4;
        } elif distance <= 80.0 {
            chance = 0.2;
        } elif distance < 500.0 {
            chance = rule.near_chance if rule.near_chance >= 0.0 else 0.1;
        } elif distance < 1000.0 {
            chance = rule.mid_chance if rule.mid_chance >= 0.0 else 0.02;
        }
        if enemy.skill <= 0 {
            chance *= 0.5;
        } elif enemy.skill >= 2 {
            chance *= 2.0;
        }
        return chance;
    }
    if melee {
        return 1.0;
    }
    has_melee = melee_reach(enemy) > 0.0;
    if distance < 120.0 {
        return 0.9;
    }
    if distance < 500.0 {
        if rule.near_chance >= 0.0 {
            return rule.near_chance;
        }
        return 0.2 if has_melee else 0.4;
    }
    if distance < 1000.0 {
        if rule.mid_chance >= 0.0 {
            return rule.mid_chance;
        }
        return 0.05 if has_melee else 0.1;
    }
    return 0.0;
}

"""Whether a monster has a ranged attack; melee-only monsters press in to
strike rather than circling."""
def shoots(enemy: Opponent) -> bool {
    ensure_profiles(enemy);
    for profile in enemy.profiles {
        if profile.kind in ["ranged", "beam"] and not profile.dodge_only {
            return True;
        }
    }
    return False;
}

"""Roll a decision's attack chance with the monster's own random stream."""
def attack_roll(enemy: Opponent, distance: float, melee: bool) -> bool {
    chance = attack_chance(enemy, distance, melee);
    if chance >= 1.0 {
        return True;
    }
    enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
    return float(enemy.shot_random) / 2147483647.0 < chance;
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
    # Weapon handling state: Q2 chaingun spin frames, BFG wind-up, machinegun
    # climb (machinegun_shots); the firing view punch; sounds and messages
    # for the game to play and print; whether the last shot keeps quiet
    # (Q3's lightning hums rather than refiring its sound); hits landed.
    has spin: int = 0,
        charge: float = 0.0,
        climb: int = 0,
        punch: float = 0.0,
        punch_time: float = 0.0,
        punch_left: float = 0.0,
        cues: list[str] = [],
        messages: list[str] = [],
        quiet: bool = False,
        firing: bool = False,
        hits: int = 0;

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
    width: float = 16.0,
    bottom: float = -24.0,
    top: float = 32.0
) -> float {
    lo = eye.sub(Vec3(x=width, y=width, z=height - bottom));
    hi = eye.add(Vec3(x=width, y=width, z=top - height - top_drop));
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

"""A segment against an opponent's own box (its SP_monster_* mins/maxs)."""
def opponent_fraction(start: Vec3, finish: Vec3, enemy: Opponent) -> float {
    return actor_fraction(
        start,
        finish,
        enemy.pos,
        enemy.eye_height,
        0.0,
        enemy.rule.width,
        enemy.rule.hull_bottom,
        enemy.rule.hull_top
    );
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
    tally: CombatState | None = None,
    bypass_protection: bool = False
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
    # g_combat.c CheckPowerArmor: a monster's power screen takes a third of
    # the damage from in front of it, one cell per point, until its cells run
    # out (the Q2 brain carries 100). Ducking brains drop the screen.
    if victim.rule.power_screen > 0
        and not bypass_armor
        and attacker is not None
        and amount > 0
        and not crouching(victim) {
        if victim.power_cells < 0 {
            victim.power_cells = victim.rule.power_screen;
        }
        toward = attacker.pos.sub(victim.pos);
        toward.z = 0.0;
        if victim.power_cells > 0
            and toward.length() > 0.001
            and toward.normalized().dot(forward_from(victim.yaw, 0.0)) > 0.3 {
            saved = min(victim.power_cells, amount // 3);
            victim.power_cells -= saved;
            amount -= saved;
        }
    }
    damage = victim spawn Damage(
        amount=amount,
        bypass_armor=bypass_armor,
        bypass_protection=bypass_protection,
        attacker=attacker,
        means=means
    );
    if state is not None and damage.dealt > 0 {
        state.hit_flash = 0.15;
        state.hits += 1;
    }
    if damage.killed {
        # Q1/Q2 Killed counts every monster death, whoever caused it; Q2
        # leaves out its AI_GOOD_GUY figures.
        if not victim.rule.inert and not victim.rule.good_guy {
            if state is not None {
                state.kills += 1;
            } elif tally is not None and not victim.arena {
                tally.kills += 1;
            }
        }
        # A raised monster's targets were cleared (m_medic.c ED_CallSpawn).
        if not victim.revived {
            victim.activation spawn Fire(inventory=inventory);
        }
        victim.visual.visible = (bool(victim.death_animation) or isinstance(victim.visual, PlayerRig))
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
    } elif attacker is not None and not victim.arena and not victim.rule.passive {
        # Q1 T_Damage / Q2 M_ReactToDamage: any hit from the player, a
        # projectile or splash included, makes the player the enemy at once,
        # even over a monster it was fighting.
        if victim.game == "q1" and victim.alert <= 0.0 {
            victim.attack_wait = max(victim.attack_wait, 1.0);
        }
        victim.foe = None;
        victim.resume_hunt = False;
        # Hitscan has already recorded the shooter with their stance.
        if victim.last_seen.sub(attacker.pos).length() > 0.001 {
            victim.last_seen = attacker.pos.add(Vec3());
            victim.last_seen_height = 22.0;
        }
        victim.alert = 8.0;
        victim.sighted = True;
        victim.decision_wait = 0.0;
    }
    if damage.dealt <= 0 {
        return 0;
    }
    # Q3 players never stop to flinch: the body twitches and cries out
    # (CG_PainEvent) while it keeps moving.
    if isinstance(victim.visual, PlayerRig) {
        victim.visual.hurt = True;
        return damage.dealt;
    }
    rule = victim.rule;
    if victim.health < victim.max_health // 2 {
        show_wounds(victim, True);
    }
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
    # m_*.c *_pain: on Nightmare a Q2 monster only cries out, with no pain
    # animation to interrupt it.
    if victim.game == "q2" and victim.skill >= 3 {
        victim.pain_cooldown = rule.pain_interval;
        if rule.pain_sounds {
            request_sound(
                victim, rule.pain_sounds[(victim.shot_random // 7919) % len(rule.pain_sounds)]
            );
        }
        return damage.dealt;
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
    victim.duck_wait = 0.0;
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

# Q2 m_*.c self->mass (misc_explobox 400); the player and the rest weigh 200.
glob Q2_MASSES: dict[str, float] = {
    "monster_soldier_light": 100.0,
    "monster_soldier": 100.0,
    "monster_soldier_ss": 100.0,
    "monster_flipper": 100.0,
    "monster_flyer": 50.0,
    "monster_hover": 150.0,
    "monster_berserk": 250.0,
    "monster_parasite": 250.0,
    "monster_mutant": 300.0,
    "monster_floater": 300.0,
    "misc_insane": 300.0,
    "monster_gladiator": 400.0,
    "monster_medic": 400.0,
    "monster_brain": 400.0,
    "misc_explobox": 400.0,
    "monster_tank": 500.0,
    "monster_tank_commander": 500.0,
    "monster_makron": 500.0,
    "monster_supertank": 800.0,
    "monster_boss2": 1000.0,
    "monster_jorg": 1000.0
};

"""Knockback, figured before armor and protection. Q1 T_Damage pushes only
walking bodies (the player) by dir*damage*8; Q2 T_Damage pushes anything that
moves by 500*knockback/mass, the rocket-jump hack using 1600 when a player
hurts himself, and nothing once killed (FL_NO_KNOCKBACK); Q3 G_Damage pushes
players and bots by g_knockback 1000 * min(damage, 200) / mass 200 and holds
off ground friction for 2 ms a point (PMF_TIME_KNOCKBACK, 50-200 ms)."""
def knock_back(
    actor: Player, game: str, direction: Vec3, amount: float, self_hit: bool = False
) {
    if amount <= 0.0 or direction.length() < 0.000001 {
        return;
    }
    if isinstance(actor, Opponent)
        and (
            actor.dormant
                or actor.rule.script
                or actor.rule.decoration
                or actor.rule.movement == "none"
        ) {
        return;
    }
    speed = 0.0;
    if game == "q2" {
        mass = 200.0;
        if isinstance(actor, Opponent) {
            if actor.health <= 0 {
                return;
            }
            mass = max(50.0, Q2_MASSES.get(actor.kind, 200.0));
        }
        human = self_hit and not isinstance(actor, Opponent);
        speed = (1600.0 if human else 500.0) * amount / mass;
    } elif game == "q3" {
        if isinstance(actor, Opponent) and not actor.arena {
            return;
        }
        knock = min(amount, 200.0);
        speed = 1000.0 * knock / 200.0;
        if actor.knockback_time <= 0.0 {
            actor.knockback_time = max(0.05, min(0.2, knock * 0.002));
        }
    } else {
        if isinstance(actor, Opponent) {
            return;
        }
        speed = amount * 8.0;
    }
    actor.velocity = actor.velocity.add(direction.normalized().scale(speed));
    if actor.velocity.z > 0.0 {
        actor.grounded = False;
    }
}

"""One hit from an opponent. Opponent victims (arena bots fighting each other,
or campaign monsters caught in infighting) go through the full opponent damage
path so they die, animate, score and retaliate. `kick` is the Q2 knockback
(-1 takes the damage); the push runs from `source` to the target."""
def strike(
    target: Player,
    amount: int,
    attacker: Opponent,
    source: Vec3 | None = None,
    means: str = "",
    tally: CombatState | None = None,
    kick: int = -1
) -> int {
    origin = source if source is not None else attacker.pos;
    push = float(amount if kick < 0 else kick);
    if isinstance(target, Opponent) {
        knock_back(target, attacker.game, target.pos.sub(origin), push);
        dealt = damage_opponent(target, amount, attacker=attacker, means=means, tally=tally);
        if dealt > 0 and target.arena {
            target.alert = max(target.alert, 8.0);
            target.last_seen = attacker.pos;
            target.foe = attacker;
        }
        return dealt;
    }
    if target.health > 0 {
        knock_back(target, attacker.game, target.pos.sub(origin), push);
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
        # Q2 lowers a corpse's box top to -8; Q3 to the corpse height. A
        # ducking Q2 monster lowers its own by 32.
        hit = actor_fraction(
            self.start,
            self.finish,
            here.pos,
            here.eye_height,
            40.0 if corpse else (32.0 if crouching(here) else 0.0),
            here.rule.width,
            here.rule.hull_bottom,
            here.rule.hull_top
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
        kick: int = -1,
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

"""Where a weapon's trail leaves the view: Q2 P_ProjectSource (7 right, 8
down), Q3 CalcMuzzlePoint and the gun's flash tag, Q1 W_FireLightning's
origin + 16 (6 below the eye)."""
def muzzle_point(player: Player, game: str) -> Vec3 {
    ahead = forward_from(player.yaw, player.pitch);
    side = right_from(player.yaw);
    up = side.cross(ahead).normalized();
    if game == "q1" {
        return player.pos.add(ahead.scale(8.0)).sub(Vec3(z=6.0));
    }
    if game == "q2" {
        return player.pos.add(ahead.scale(8.0)).add(side.scale(7.0)).sub(up.scale(8.0));
    }
    return player.pos.add(ahead.scale(14.0)).add(side.scale(5.0)).sub(up.scale(6.0));
}

"""Q1 W_FireLightning under water (waterlevel above 1): every cell goes at
once as T_RadiusDamage(self, self, 35 * cells), the shooter taking half."""
def discharge_lightning(
    world: World, player: Player, collision: CollisionMap, state: CombatState, rule: WeaponRule
) {
    cells = quantity(player.inventory, rule.ammo);
    player.inventory spawn AdjustInventory(kind=rule.ammo, amount=-cells);
    state.cooldown = rule.interval * fire_interval_scale(player);
    state.flash = 0.08;
    state.shots += 1;
    amount = int(float(35 * cells) * damage_scale(player, state.game));
    center = player.pos.sub(Vec3(z=collision.eye_height - 4.0));
    blast_actors(world, center, amount, float(amount + 40), False, player, collision, state);
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
    direction = forward_from(player.yaw, player.pitch);
    # Q3 PM_Weapon: the gauntlet only "fires" when it touches someone.
    if state.game == "q3" and rule.key == "gauntlet" {
        reach = player.pos.add(direction.scale(rule.reach));
        wall = collision.trace_point(player.pos, reach);
        touch = world spawn Aim(
            start=player.pos, finish=reach, height=collision.eye_height, fraction=wall.fraction
        );
        if touch.target is None {
            return False;
        }
    }
    if state.game == "q1" and rule.key == "lightning" and player.water_depth > 1 {
        discharge_lightning(world, player, collision, state, rule);
        return True;
    }
    if rule.ammo {
        player.inventory spawn AdjustInventory(kind=rule.ammo, amount=-rule.cost);
    }
    scale = damage_scale(player, state.game);
    state.cooldown = rule.interval * fire_interval_scale(player);
    state.flash = 0.08;
    state.shots += 1;
    state.impact_model = -1;
    if rule.punch > 0.0 {
        state.punch = rule.punch;
        state.punch_time = rule.punch_time;
        state.punch_left = rule.punch_time;
    }
    # Q2 Machinegun_Fire: each shot of a burst aims 1.5 degrees higher,
    # up to nine (machinegun_shots), and the view climbs with it.
    if state.game == "q2" and rule.key == "machinegun" {
        climb = 1.5 * float(state.climb);
        direction = forward_from(player.yaw, player.pitch + math.radians(climb));
        state.punch = climb;
        state.punch_time = 0.1;
        state.punch_left = 0.1;
        state.climb = min(9, state.climb + 1);
    }
    side = right_from(player.yaw);
    up = side.cross(direction).normalized();
    if rule.speed > 0.0 {
        velocity = direction.scale(rule.speed);
        if rule.gravity and state.game == "q3" {
            # g_weapon.c weapon_grenadelauncher_fire: aim a little upward.
            velocity = direction.add(Vec3(z=0.2)).normalized().scale(rule.speed);
        } elif rule.gravity {
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
            burst_radius=rule.burst_radius,
            kick=int(float(rule.kick) * scale) if rule.kick >= 0 else -1
        );
        if state.game == "q2" and rule.effect in ["q2_bolt", "q2_rocket"] {
            check_dodge(world, player, direction, collision, state);
        }
        state.target = player.pos;
        return True;
    }
    # Aggregate pellet damage before armor, death targets and kill credit.
    victims: list[Opponent] = [];
    amounts: list[int] = [];
    kicks: list[float] = [];
    for pellet in range(rule.pellets) {
        shot = direction;
        if rule.spread > 0.0 and rule.circular {
            # Q3 Bullet_Fire: a random angle around the aim, a random reach.
            turn = (state.random() + 1.0) * math.pi;
            shot = shot.add(side.scale(math.cos(turn) * state.random() * rule.spread)).add(
                up.scale(math.sin(turn) * state.random() * rule.spread)
            );
        } elif rule.spread > 0.0 {
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
                    and opponent_fraction(player.pos, finish, enemy) < wall.fraction {
                    hits.append(enemy);
                }
            }
            # Q2 fire_rail TE_RAILTRAIL / Q3 CG_RailTrail, to the wall.
            if state.game in ["q2", "q3"] {
                rail_trail(
                    world,
                    muzzle_point(player, state.game),
                    player.pos.lerp(finish, wall.fraction),
                    state.game + "_rail"
                );
            }
        } elif query.target is not None {
            hits.append(query.target);
        }
        if rule.key == "lightning" {
            # Q1 TE_LIGHTNING2 (bolt2.mdl) / Q3 CG_LightningBolt, to the hit.
            beam_trail(
                world,
                muzzle_point(player, state.game),
                player.pos.lerp(finish, query.fraction),
                "player_lightning"
            );
        }
        for victim in hits {
            fraction = opponent_fraction(player.pos, finish, victim);
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
                kicks.append(0.0);
            }
            amounts[victims.index(victim)] += int(float(rule.damage) * scale);
            kicks[victims.index(victim)] += float(
                rule.kick if rule.kick >= 0 else rule.damage
            )
                * scale;
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
        # Q2 fire_lead / Q3 Bullet_Fire push along the aim.
        knock_back(victims[i], state.game, direction, kicks[i]);
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

"""The BFG's wind-up: when it ends the cells are checked again, since power
armor may have spent them, and the orb leaves."""
def bfg_wind_up(
    world: World,
    player: Player,
    collision: CollisionMap,
    state: CombatState,
    rule: WeaponRule,
    dt: float
) -> bool {
    state.charge = max(0.0, state.charge - dt);
    if state.charge > 0.000001 {
        return False;
    }
    rest = state.cooldown;
    state.cooldown = 0.0;
    if rule.key == "bfg" and fire_weapon(world, player, collision, state) {
        state.cooldown = max(0.0, rest);
    } else {
        state.cooldown = rest;
    }
    return False;
}

"""p_weapon.c Chaingun_Fire: at 10 frames a second it fires one bullet a
frame for five frames, two for the next five, then three while the trigger
holds; chngnu1a.wav spins it up and chngnd1a.wav winds it down."""
def chaingun_frame(
    world: World,
    player: Player,
    collision: CollisionMap,
    state: CombatState,
    rule: WeaponRule,
    held: bool
) -> bool {
    if not held {
        if state.spin > 10 {
            state.cues.append("sound/weapons/Chngnd1a.wav");
        }
        state.spin = 0;
        return False;
    }
    if state.cooldown > 0.000001 {
        return False;
    }
    if quantity(player.inventory, rule.ammo) < rule.cost {
        state.spin = 0;
        out_of_ammo(player, state);
        return False;
    }
    state.spin += 1;
    if state.spin == 1 {
        state.cues.append("sound/weapons/Chngnu1a.wav");
    }
    shots = 1 if state.spin <= 5 else (2 if state.spin <= 10 else 3);
    fired = False;
    for shot in range(shots) {
        state.cooldown = 0.0;
        if fire_weapon(world, player, collision, state) {
            fired = True;
        }
    }
    state.cooldown = 0.1 * fire_interval_scale(player);
    return fired;
}

"""Firing without ammo: Q2 and Q3 click (noammo.wav), then all change to the best weapon with ammo (Q1 W_CheckNoAmmo,
Q2 NoAmmoWeaponChange, Q3 CG_OutOfAmmoChange)."""
def out_of_ammo(player: Player, state: CombatState) {
    if state.game in ["q2", "q3"] {
        state.cues.append("sound/weapons/noammo.wav");
    }
    fallback_weapon(player, state);
}

"""The weapon a slot names, if the rules have one."""
def weapon_rule(state: CombatState, slot: int) -> WeaponRule | None {
    for rule in state.rules {
        if rule.slot == slot {
            return rule;
        }
    }
    return None;
}

def has_ammo_for(player: Player, rule: WeaponRule) -> bool {
    return not rule.ammo or quantity(player.inventory, rule.ammo) >= rule.cost;
}

"""Swap to `slot`, holding fire while the old weapon lowers and the new one
rises: Q1 changes at once, Q2 plays each weapon's deactivate and activate
frames, Q3 drops for 200 ms and raises for 250 ms (bg_pmove.c)."""
def swap_weapon(state: CombatState, rule: WeaponRule) {
    old = selected_weapon(state);
    state.weapon = rule.slot;
    state.spin = 0;
    state.climb = 0;
    state.charge = 0.0;
    state.cooldown = max(state.cooldown, old.lower_time + rule.raise_time);
}

"""The player's weapon command: Q1 W_ChangeWeapon ("no weapon.", "not enough
ammo."), Q2 Use_Weapon ("No shells for Shotgun."), Q3 CG_Weapon_f (silently
refuses a weapon without ammo). Returns whether the weapon changed."""
def change_weapon(player: Player, state: CombatState, slot: int) -> bool {
    if state.grenade_phase > 0 or state.charge > 0.0 or not state.rules {
        return select_weapon(player, state, slot);
    }
    rule = weapon_rule(state, slot);
    if rule is None or not owns_weapon(player, rule) {
        if state.game == "q1" {
            state.messages.append("no weapon.");
        } elif state.game == "q2" and rule is not None {
            state.messages.append("Out of item: " + rule.name);
        }
        return False;
    }
    if not has_ammo_for(player, rule) {
        if state.game == "q1" {
            state.messages.append("not enough ammo.");
        } elif state.game == "q2" {
            state.messages.append(
                ("No " if quantity(player.inventory, rule.ammo) == 0 else "Not enough ")
                    + rule.ammo
                    + " for "
                    + rule.name
                    + "."
            );
        }
        return False;
    }
    if rule.slot == state.weapon {
        return False;
    }
    swap_weapon(state, rule);
    return True;
}

"""Next or previous weapon (Q1 impulse 10/12 CycleWeaponCommand, Q2
weapnext/weapprev, Q3 CG_NextWeapon_f): the nearest slot either way that
holds an owned weapon with ammo."""
def cycle_weapon(player: Player, state: CombatState, step: int) -> bool {
    if step == 0 or not state.rules or state.grenade_phase > 0 or state.charge > 0.0 {
        return False;
    }
    slots = sorted([rule.slot for rule in state.rules]);
    if state.weapon not in slots {
        return False;
    }
    here = slots.index(state.weapon);
    for offset in range(1, len(slots)) {
        rule = weapon_rule(state, slots[(here + offset * step) % len(slots)]);
        if rule is not None and owns_weapon(player, rule) and has_ammo_for(player, rule) {
            swap_weapon(state, rule);
            return True;
        }
    }
    return False;
}

"""Changing to a picked-up weapon: Q1 weapon_touch always does in single
player; Q2 Pickup_Weapon does the first time one is picked up; Q3
CG_ItemPickup (cg_autoswitch) does for any weapon but the machinegun."""
def pickup_switch(player: Player, state: CombatState, key: str, fresh: bool) -> bool {
    if state.grenade_phase > 0 or state.charge > 0.0 {
        return False;
    }
    for rule in state.rules {
        if rule.key != key or rule.slot == state.weapon or not owns_weapon(player, rule) {
            continue;
        }
        if (state.game == "q2" and not fresh) or (state.game == "q3" and key == "machinegun") {
            return False;
        }
        swap_weapon(state, rule);
        return True;
    }
    return False;
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
                swap_weapon(state, rule);
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
    was_firing = state.firing;
    state.firing = held;
    state.quiet = False;
    state.punch_left = max(0.0, state.punch_left - dt);
    if not held {
        state.climb = 0;
    }
    if state.charge > 0.0 {
        return bfg_wind_up(world, player, collision, state, rule, dt);
    }
    if state.game == "q2" and rule.key == "chaingun" {
        return chaingun_frame(world, player, collision, state, rule, held);
    }
    if state.grenade_phase == 0 {
        if not held or state.cooldown > 0.000001 {
            return False;
        }
        if rule.ammo and quantity(player.inventory, rule.ammo) < rule.cost {
            out_of_ammo(player, state);
            return False;
        }
        # p_weapon.c weapon_bfg_fire: the muzzle flash and sound at gunframe
        # 9, the orb itself eight frames later.
        if state.game == "q2" and rule.key == "bfg" {
            state.charge = 0.8;
            state.flash = 0.08;
            state.cooldown = rule.interval * fire_interval_scale(player);
            return True;
        }
        if not rule.hand_thrown {
            fired = fire_weapon(world, player, collision, state);
            # cg_weapons.c: the lightning gun sounds lg_fire once, then hums.
            if fired and state.game == "q3" and rule.key == "lightning" and was_firing {
                state.quiet = True;
                if state.shots % 12 == 0 {
                    state.cues.append("sound/weapons/lightning/lg_hum.wav");
                }
            }
            return fired;
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
        body = actor.pos.sub(Vec3(z=height));
        center = body.add(Vec3(z=4.0));
        distance = center.sub(origin).length();
        if state.game == "q3" {
            # G_RadiusDamage measures from the nearest point of the box.
            width = actor.rule.width if isinstance(actor, Opponent) else 15.0;
            gap = Vec3(
                x=max(0.0, abs(origin.x - body.x) - width),
                y=max(0.0, abs(origin.y - body.y) - width),
                z=max(0.0, body.z - 24.0 - origin.z, origin.z - body.z - 32.0)
            );
            distance = gap.length();
        }
        if distance >= radius {
            continue;
        }
        sight = collision.trace_point(origin, center);
        if sight.start_solid or sight.fraction < 1.0 {
            continue;
        }
        strength = blast_strength(state.game, splash, radius, distance);
        # Q1/Q2 T_RadiusDamage and Q3 G_Damage halve an attacker's own
        # splash; Q3 figures the knockback before halving (rocket jumps).
        self_hit = (actor is player and not hostile)
            or (hostile and attacker is not None and actor is attacker);
        push = strength;
        if self_hit {
            strength *= 0.5;
            if state.game != "q3" {
                push = strength;
            }
        }
        if isinstance(actor, Opponent) {
            strength *= actor.rule.blast_scale;
        }
        amount = int(strength);
        if not corpse {
            # Q3 pushes the centre of mass 24 units higher.
            away = body.sub(origin).add(Vec3(z=24.0 if state.game == "q3" else 0.0));
            knock_back(actor, state.game, away, float(int(push)), self_hit);
        }
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
    }
}

"""A missile's direct hit pushes along its flight (Q3 G_MissileImpact, Q2
touch functions) or away from it (Q1 T_Damage). Q2 rockets and the BFG pass
no knockback on contact; their blast does the pushing."""
def missile_knock(projectile: Projectile, victim: Player, game: str) {
    amount = float(projectile.damage);
    if projectile.kick >= 0 {
        amount = float(projectile.kick);
    } elif game == "q2" and projectile.splash > 0 and not projectile.gravity {
        amount = 0.0;
    }
    if game in ["q2", "q3"] {
        knock_back(victim, game, projectile.velocity, amount);
    } else {
        knock_back(victim, game, victim.pos.sub(projectile.pos), amount);
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
    explode(world, projectile.pos, blast_kind(state.game, projectile.effect));
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
    # Q1 barrels BecomeExplosion; Q2 barrel_explode shows the grenade burst on
    # the ground and the rocket burst in the air, as flyer_die does.
    kind = blast_kind(state.game, "q2_grenade" if enemy.grounded else "q2_rocket");
    explode(world, origin, kind);
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
            player spawn Damage(
                amount=projectile.beam_damage, source=projectile.pos, energy=True
            );
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
            if opponent_fraction(projectile.pos, finish, victim) < trace.fraction {
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
                source=projectile.pos,
                energy=True
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
        struck: Player | None = self.player if player_hit else victim;
        if struck is not None {
            missile_knock(here, struck, self.state.game);
        }
        if player_hit {
            self.player spawn Damage(
                amount=here.damage,
                source=here.pos.sub(here.velocity.normalized()),
                attacker=here.owner,
                energy=self.state.game == "q2" and here.effect in ["q2_bolt", "q2_bfg"]
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
            # Q3 G_BounceMissile keeps 65% and rests below 40 u/s on any
            # floor steeper than 0.2.
            arena = self.state.game == "q3";
            here.velocity = here.velocity.sub(
                wall.normal.scale(2.0 * here.velocity.dot(wall.normal))
            ).scale(
                0.65 if arena else 0.5
            );
            here.pos = here.pos.add(wall.normal.scale(0.1));
            if wall.normal.z > (0.2 if arena else 0.7) and here.velocity.length() < 40.0 {
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

def begin_attack(enemy: Opponent, index: int, target: Vec3) {
    select_profile(enemy, index);
    profile = enemy.profiles[index];
    enemy.attack_target = target.add(Vec3());
    enemy.attack_clock = 0.0;
    enemy.attack_event = 0;
    enemy.burst_count = 1;
    if profile.burst_max > 1 and not enemy.attack_melee {
        enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
        enemy.burst_count = profile.burst_min
            + enemy.shot_random % (profile.burst_max - profile.burst_min + 1);
    }
    enemy.attack_wait = attack_duration(enemy)
        + attack_pause(enemy, melee=profile.kind == "melee");
    enemy.attack_flash = attack_duration(enemy);
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
        if profile.dodge_only or profile.kind == "revive" {
            continue;
        }
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

def launch_missile(
    world: World, enemy: Opponent, direction: Vec3, profile: AttackProfile, quarry: Player
) {
    velocity = direction.scale(profile.missile_speed);
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
        quarry=quarry
    );
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
        # Each further shot of a burst sounds again (the muzzle flash event).
        if enemy.burst_count > 1 and event_index > 0 and speaker is not None {
            speaker.requests += 1;
        }
        if profile.kind == "revive" {
            if isinstance(player, Opponent) {
                at = profile.times[event_index]
                    if event_index < len(profile.times)
                    else -1.0;
                cable_event(world, enemy, player, profile, at, collision, person);
            }
            continue;
        }
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
                # Q2 fire_hit adds its own kick below (DAMAGE_NO_KNOCKBACK).
                dealt = strike(
                    player,
                    amount,
                    enemy,
                    source=enemy.pos,
                    tally=tally,
                    kick=0 if enemy.game == "q2" else -1
                );
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
                launch_missile(world, enemy, aimed, profile, player);
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

"""Telefrags (Q1 spawn_tdeath, Q2 KillBox, Q3 G_KillBox): an actor arriving
with its origin at `origin` kills every other actor its box overlaps, through
armor and protection. Q3 only kills players and bots; Q1's teleport-death box
reaches a unit further."""
walker KillBox {
    has mover: Player,
        origin: Vec3,
        game: str = "",
        bystander: Player | None = None,
        bystander_height: float = 22.0,
        tally: CombatState | None = None,
        victims: int = 0;

    def overlaps(actor: Player, height: float) -> bool {
        other = actor.pos.sub(Vec3(z=height));
        pad = 1.0 if self.game == "q1" else 0.0;
        return abs(other.x - self.origin.x) < 32.0 + pad
            and abs(other.y - self.origin.y) < 32.0 + pad
            and abs(other.z - self.origin.z) < 56.0 + pad;
    }

    can begin with World entry {
        person = self.bystander;
        if person is not None
            and person is not self.mover
            and person.health > 0
            and self.overlaps(person, self.bystander_height) {
            person spawn Damage(
                amount=100000,
                bypass_armor=True,
                bypass_protection=True,
                means="telefrag",
                attacker=self.mover
            );
            self.victims += 1;
        }
        visit [here->:HasOpponent:->];
    }

    can strike with Opponent entry {
        if here is self.mover or here.health <= 0 or here.dormant {
            return;
        }
        if self.game == "q3" and not here.arena {
            return;
        }
        if not self.overlaps(here, here.eye_height) {
            return;
        }
        damage_opponent(
            here,
            100000,
            bypass_armor=True,
            attacker=self.mover,
            means="telefrag",
            tally=self.tally,
            bypass_protection=True
        );
        self.victims += 1;
    }
}

"""The seconds a Q2 duck lasts: its frames at 10 Hz, holding the hold frame
until a second after the duck-down frame (monster_duck_down sets pausetime)."""
def duck_length(enemy: Opponent) -> float {
    rule = enemy.rule;
    extra = max(0, rule.duck_down + 10 - rule.duck_hold);
    return float(len(rule.duck_frames) + extra) / 10.0;
}

def duck_pose_time(enemy: Opponent) -> float {
    rule = enemy.rule;
    elapsed = max(0.0, duck_length(enemy) - enemy.duck_wait) * 10.0;
    extra = float(max(0, rule.duck_down + 10 - rule.duck_hold));
    hold = float(rule.duck_hold);
    if elapsed < hold {
        return elapsed;
    }
    if elapsed < hold + extra {
        return hold;
    }
    return elapsed - extra;
}

"""Whether the monster's box top is lowered 32 units: between the duck-down and
duck-up frames of a duck, or through a crouched attack's window."""
def crouching(enemy: Opponent) -> bool {
    if enemy.health <= 0 {
        return False;
    }
    if enemy.duck_wait > 0.0 {
        pose = duck_pose_time(enemy);
        return pose >= float(enemy.rule.duck_down) and pose < float(enemy.rule.duck_up);
    }
    if enemy.attack_clock >= 0.0 and enemy.attack_profile >= 0 {
        profile = current_profile(enemy);
        return profile.crouch_start >= 0.0
            and enemy.attack_clock >= profile.crouch_start
            and enemy.attack_clock < profile.crouch_end;
    }
    return False;
}

"""A Q2 monster's dodge (soldier_dodge, infantry_dodge, gunner_dodge,
chick_dodge, medic_dodge, brain_dodge): a quarter of the time it takes the
shooter as its enemy and ducks, interrupting whatever it was doing. Soldiers
on medium and hard sometimes crouch and fire instead."""
walker Dodge {
    has shooter: Player,
        roll: float,
        choice: float,
        grenade_roll: float = 0.0,
        world: World | None = None,
        ducked: bool = False;

    can duck with Opponent entry {
        rule = here.rule;
        if not rule.duck_frames or not here.duck_animation or here.health <= 0 or here.pain_down {
            return;
        }
        if self.roll > 0.25 {
            return;
        }
        if here.alert <= 0.0 and here.foe is None {
            here.last_seen = self.shooter.pos.add(Vec3());
            here.last_seen_height = 22.0;
            here.alert = 8.0;
        }
        here.pain_wait = 0.0;
        here.leaping = False;
        here.attack_flash = 0.0;
        here.attack_clock = -1.0;
        here.attack_profile = -1;
        ensure_profiles(here);
        crouch = -1;
        for i in range(len(here.profiles)) {
            if here.profiles[i].dodge_only {
                crouch = i;
            }
        }
        # soldier_dodge: easy always ducks; medium ducks two times in three
        # and hard one in three, otherwise attack3.
        threshold = 0.33 if here.skill == 1 else 0.66;
        if crouch >= 0 and here.skill >= 1 and self.choice <= threshold {
            here.duck_wait = 0.0;
            begin_attack(here, crouch, self.shooter.pos);
        } else {
            here.duck_wait = duck_length(here);
            # gunner_duck_down: on hard, half the time lob a grenade straight
            # ahead going down (GunnerGrenade fires along the gunner's facing).
            world = self.world;
            if rule.duck_grenade and here.skill >= 2 and self.grenade_roll > 0.5 and world is not None {
                for profile in here.profiles {
                    if profile.name == rule.duck_grenade {
                        ahead = Vec3(x=math.cos(here.yaw), y=math.sin(here.yaw));
                        launch_missile(world, here, ahead, profile, self.shooter);
                    }
                }
            }
        }
        self.ducked = True;
    }
}

"""g_weapon.c check_dodge: a player's blaster bolt or rocket warns the first
monster along its line, if that monster faces the shooter. On easy the warning
itself comes only a quarter of the time."""
def check_dodge(
    world: World,
    player: Player,
    direction: Vec3,
    collision: CollisionMap,
    state: CombatState
) -> Opponent | None {
    finish = player.pos.add(direction.scale(8192.0));
    wall = collision.trace_point(player.pos, finish);
    query = world spawn Aim(
        start=player.pos,
        finish=finish,
        height=collision.eye_height,
        fraction=wall.fraction
    );
    target = query.target;
    if target is None or target.health <= 0 or target.arena {
        return None;
    }
    if target.skill == 0 and state.random() * 0.5 + 0.5 > 0.25 {
        return None;
    }
    # infront(target, shooter): the shooter is within the monster's forward cone.
    toward = player.pos.sub(target.pos);
    toward.z = 0.0;
    if toward.length() < 0.000001 {
        return None;
    }
    facing = Vec3(x=math.cos(target.yaw), y=math.sin(target.yaw));
    if facing.dot(toward.normalized()) <= 0.3 {
        return None;
    }
    target spawn Dodge(
        shooter=player,
        roll=state.random() * 0.5 + 0.5,
        choice=state.random() * 0.5 + 0.5,
        grenade_roll=state.random() * 0.5 + 0.5,
        world=world
    );
    return target;
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

    """A medic's current patient, searching twice a second for a new one."""
    def tend(medic: Opponent) -> Opponent | None {
        for patient in [medic->:Mends:->][?:Opponent] {
            if patient.health <= 0 and not patient.gibbed and patient.visual.visible {
                return patient;
            }
            medic del --> patient;
        }
        world = self.world;
        medic.tend_wait -= self.dt;
        if world is None or medic.tend_wait > 0.0 or medic.attack_clock >= 0.0 {
            return None;
        }
        medic.tend_wait = 0.5;
        search = world spawn FindPatient(medic=medic, collision=self.collision);
        found = search.best;
        if found is not None {
            medic +>:Mends:+> found;
        }
        return found;
    }

    """Q1 CheckAttack / Q2 M_CheckAttack: hold a ranged attack unless the
    shot from the eye reaches the target, not another monster in the way."""
    def clear_shot(shooter: Opponent, target: Player, profile: AttackProfile) -> bool {
        world = self.world;
        if profile.kind == "melee" or world is None {
            return True;
        }
        query = world spawn Aim(
            start=shooter.pos,
            finish=target.pos,
            height=self.collision.eye_height,
            ignore=shooter
        );
        return query.target is None or query.target is target;
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

    """A Q3 body follows its bot the way bg_pmove.c animates every player:
    legs from its movement, torso from its weapon, and cg_event.c's sounds
    from where it stands."""
    def pose_body(bot: Opponent, rig: PlayerRig, wish: Vec3) {
        switching = "";
        if bot.character is not None and bot.health > 0 {
            if bot.weapon_change < 0.2 {
                switching = "drop";
            } elif bot.weapon_change < WEAPON_SWITCH_TIME {
                switching = "raise";
            }
        }
        hurt = rig.hurt;
        rig.hurt = False;
        pose = rig spawn PoseRig(
            dt=self.dt,
            grounded=bot.grounded,
            velocity=bot.velocity,
            wish=wish,
            yaw=bot.yaw,
            pitch=bot.pitch,
            water_depth=bot.water_depth,
            crouched=bot.crouched,
            alive=bot.health > 0,
            health=bot.health,
            hurt=hurt,
            switching=switching,
            ready=bot.weapon_wait <= 0.0,
            shots=rig.shots,
            haste=empowered(bot, "haste")
        );
        for cue in pose.sounds {
            request_sound(bot, rig_sound(rig, cue));
        }
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
        here spawn CorpseTick(dt=self.dt);
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
            corpse = here.visual;
            if isinstance(corpse, PlayerRig) {
                # TossClientItems as the body starts to fall.
                if corpse.alive and self.world is not None {
                    toss_items(self.world, here, here.shown_weapon, self.collision, here.eye_height);
                }
                self.pose_body(here, corpse, Vec3());
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
            # Q1 DropBackpack / Q2 Drop_Item: the carried item lands at the
            # body's feet (Q2 items sit 15 units up, as droptofloor leaves them).
            for item in [here->:Drops:->][?:Pickup] {
                body = here.pos.sub(Vec3(z=here.eye_height));
                floor = self.collision.trace_point(body, body.sub(Vec3(z=128.0)));
                landing = body.lerp(body.sub(Vec3(z=128.0)), floor.fraction);
                item.pos = landing.add(Vec3(z=15.0 if here.game == "q2" else 0.0));
                item.active = True;
                item.released = True;
                item.visual.visible = True;
                area = area_of(here);
                if area is not None {
                    move_to_area(item, area);
                }
                here del --> item;
            }
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
            # BossExplode: a settled Q2 boss wreck blows apart.
            if here.rule.explodes
                and not here.gibbed
                and here.death_animation
                and here.animation_time >= float(len(here.death_animation)) - 1.0 {
                burst(here, 0);
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
            # CopyToBodyQue: the old body stays where it fell.
            if isinstance(corpse, PlayerRig) and self.world is not None {
                leave_corpse(self.world, here, corpse);
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
            here.pitch = 0.0;
            here.crouched = False;
            here.bot_state = BotState();
            here.pose_name = "";
            here.pos = destination;
            # g_client.c ClientSpawn: G_KillBox telefrags whoever stands there.
            if self.world is not None {
                self.world spawn KillBox(
                    mover=here,
                    origin=destination.sub(Vec3(z=here.eye_height)),
                    game="q3",
                    bystander=self.player,
                    bystander_height=self.collision.eye_height,
                    tally=self.state
                );
            }
            here.route = [];
            here.route_areas = [];
            here.route_wait = 0.0;
            here.velocity = Vec3();
            here.visual.visible = True;
            if isinstance(corpse, PlayerRig) {
                reset_rig(corpse, math.degrees(spawn_yaw));
            }
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
            # ai_main.c: a bot looks for enemies at its think rate (10 Hz), not
            # every physics tick, and keeps its enemy in between. Each bot
            # starts at its own decision offset, so their looks are staggered.
            if here.foe_wait < 0.0 {
                here.foe_wait = max(0.0, here.decision_wait);
            }
            here.foe_wait -= self.dt;
            current = here.foe;
            if here.foe_wait <= 0.0 or (current is not None and current.health <= 0) {
                here.foe_wait = 0.1;
                foe = self.select_foe(here);
            } elif current is not None {
                foe = current;
            }
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
        # Q2 m_medic.c: a medic makes the best corpse in sight its enemy
        # (AI_MEDIC), runs to it and raises it with its cable.
        patient: Opponent | None = None;
        if here.rule.medic and here.health > 0 {
            patient = self.tend(here);
            if patient is not None {
                foe = patient;
                here.alert = max(here.alert, 3.0);
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
        here.duck_wait = max(0.0, here.duck_wait - self.dt);
        if here.pain_wait <= 0.0 and here.pain_down {
            here.pain_down = False;
            here.pain_variant = 0;
        }
        here.pain_cooldown = max(0.0, here.pain_cooldown - self.dt);
        here.attack_wait = max(0.0, here.attack_wait - self.dt);
        here.attack_flash = max(0.0, here.attack_flash - self.dt);
        here.alert = max(0.0, here.alert - self.dt);
        here.route_wait = max(0.0, here.route_wait - self.dt);
        here.slide_wait = max(0.0, here.slide_wait - self.dt);
        # Q2 ai_stand / Q1 idle frames: an unalerted monster mutters now and
        # then, every 15 to 30 seconds.
        if here.alert <= 0.0 and here.rule.idle_sound {
            here.idle_wait -= self.dt;
            if here.idle_wait <= 0.0 {
                if here.idle_wait > -1.0 {
                    request_sound(here, here.rule.idle_sound);
                }
                here.shot_random = (here.shot_random * 48271) % 2147483647;
                here.idle_wait = 15.0
                    * (1.0 + float(here.shot_random) / 2147483647.0);
            }
        }
        here.decision_wait -= self.dt;
        if here.decision_wait <= 0.0 and self.decisions < 8 {
            self.decisions += 1;
            here.decision_wait = 0.1;
            here.pursuing = False;
            was_alert = here.alert > 0.0;
            if distance < 1500.0 {
                sight = self.collision.trace_point(here.pos, foe.pos);
                # Q2 AI_GOOD_GUY (misc_insane): passive figures never hunt.
                here.pursuing = not sight.start_solid
                    and sight.fraction == 1.0
                    and not here.rule.passive;
                if here.pursuing and not was_alert and not here.arena {
                    here.pursuing = notices(here, foe.pos, distance, self.state.noise > 0.0);
                }
                if not here.pursuing and not was_alert and not here.arena and not here.ambush {
                    # Q2 PlayerNoise: gunfire is heard within 1000 units.
                    if here.game == "q2"
                        and self.state.noise > 0.0
                        and distance < 1000.0
                        and here.heard {
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
                    if here.game == "q2" and foe is self.player and self.world is not None {
                        here.trail_stamp = trail_clock(self.world);
                    }
                    if not was_alert and not here.sighted {
                        # Q1 ai.qc HuntTarget: SUB_AttackFinished(1), a moment
                        # to react before a newly woken monster first fires.
                        if here.game == "q1" and not here.arena {
                            here.attack_wait = max(here.attack_wait, 1.0);
                        }
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
                    and here.duck_wait <= 0.0
                    and here.attack_clock < 0.0
                    and not here.leaping {
                    selected = choose_attack(here, distance);
                    if patient is not None {
                        selected = -1;
                        for i in range(len(here.profiles)) {
                            if here.profiles[i].kind == "revive"
                                and distance <= here.profiles[i].max_range {
                                selected = i;
                            }
                        }
                        if selected >= 0 {
                            begin_attack(here, selected, foe.pos);
                            selected = -1;
                        }
                    }
                    if selected >= 0
                        and attack_roll(
                            here, distance, here.profiles[selected].kind == "melee"
                        )
                        and self.clear_shot(here, foe, here.profiles[selected]) {
                        begin_attack(here, selected, foe.pos);
                    } elif here.rule.slides and here.slide_wait <= 0.0 {
                        # Q2 M_CheckAttack / Q1 WizardCheckAttack: a flier that
                        # holds its fire side-steps (AS_SLIDING) about a third
                        # of the time; held briefly rather than re-rolled.
                        here.shot_random = (here.shot_random * 48271) % 2147483647;
                        roll = float(here.shot_random) / 2147483647.0;
                        if roll < 0.3 {
                            here.slide_wait = 0.6 + 2.6 * roll;
                        }
                    }
                }
            }
            if here.alert <= 0.0 and not here.pursuing {
                here.sighted = False;
            }
            # Q2 ai_run: out of sight at the last-seen spot, hunt along the
            # player's trail, crumb by crumb, from where the monster lost them.
            if here.game == "q2"
                and not here.arena
                and here.alert > 0.0
                and not here.pursuing
                and foe is self.player
                and self.world is not None {
                lost = here.last_seen.sub(here.pos);
                if math.sqrt(lost.x * lost.x + lost.y * lost.y) < 48.0 {
                    crumb = next_crumb(self.world, here.trail_stamp);
                    if crumb is not None {
                        here.last_seen = crumb.pos.add(Vec3());
                        here.last_seen_height = self.collision.eye_height;
                        here.trail_stamp = crumb.stamp;
                        here.alert = max(here.alert, 3.0);
                    }
                }
            }
            # Q1 ai_run keeps its enemy until one of them dies, and movetogoal
            # steers at the enemy itself whether it is visible or not, so a
            # woken monster follows the player through the level.
            if here.game == "q1"
                and not here.arena
                and here.alert > 0.0
                and not here.pursuing
                and foe.health > 0 {
                here.last_seen = foe.pos.add(Vec3());
                here.last_seen_height = foe_height;
                here.alert = 8.0;
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
            closing = here.pursuing
                and patient is None
                and here.arena_goal is None
                and patrol is None
                and len(here.route) <= 1;
            stop = here.rule.stop_range if closing else 12.0;
            # ai_run_slide: circle the target instead of standing still, both
            # when sliding and, for every monster, once it has closed in.
            circling = closing
                and here.character is None
                and (here.slide_wait > 0.0 or (goal.length() <= stop and shoots(here)));
            if (here.alert > 0.0 or patrol is not None)
                and not here.fighting
                and here.pain_wait <= 0.0
                and here.attack_flash <= 0.0
                and not here.leaping
                and here.rule.movement != "none"
                and (circling or goal.length() > stop) {
                direction = Vec3(x=goal.x, y=goal.y).normalized();
                if circling {
                    # Sideways with a slight inward pull, so the circle holds
                    # its radius instead of spiralling out.
                    side = 1.0 if here.lefty else -1.0;
                    direction = Vec3(
                        x=-direction.y * side + direction.x * 0.3,
                        y=direction.x * side + direction.y * 0.3
                    ).normalized();
                }
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
                            if circling {
                                if angle == 0.0 {
                                    here.lefty = not here.lefty;
                                }
                                continue;
                            }
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
                    # A blocked slide turns to the other side (ai_run_slide).
                    if circling and angle == 0.0 and probe.fraction < 1.0 {
                        here.lefty = not here.lefty;
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
        # bg_pmove.c pm_duckScale: crouching Q3 bots move at a quarter speed.
        if here.crouched and here.character is not None {
            here.walk_speed *= 0.25;
        }
        if strolling {
            here.walk_speed = here.patrol_speed
                if here.patrol_speed > 0.0
                else here.rule.speed * 0.4;
        }
        # Bots keep steering over stair steps and drops, but not while a jump or
        # pad launch is still carrying them upward.
        wish = Vec3()
            if here.pain_wait > 0.0
                or here.duck_wait > 0.0
                or (here.attack_flash > 0.0 and here.character is None)
                or here.leaping
                or (here.arena and not here.grounded and here.velocity.z > 100.0)
            else here.steering;
        facing = here.patrol_goal;
        if facing is None and here.alert > 0.0 {
            facing = here.last_seen;
        }
        if facing is not None and not here.fighting and here.character is None {
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
                    before = here.pos.add(Vec3());
                    here spawn MovePlayer(
                        collision=body_collision,
                        wish=wish,
                        dt=self.dt,
                        steady=strolling
                    );
                    here.support_wait = 0.05;
                    # SV_movestep: a monster cannot step into the player
                    # (a leap is a toss that lands on it instead).
                    if self.player.health > 0
                        and not here.leaping
                        and actor_overlap(
                            self.player.pos.sub(Vec3(z=self.collision.eye_height)),
                            self.collision.top_drop,
                            here
                        ) is not None
                        and box_overlap(
                            self.player.pos.sub(Vec3(z=self.collision.eye_height)),
                            self.collision.top_drop,
                            before.sub(Vec3(z=here.eye_height)),
                            here.rule.width,
                            here.rule.hull_bottom,
                            here.rule.hull_top
                        ) is None {
                        here.pos = Vec3(x=before.x, y=before.y, z=here.pos.z);
                        here.velocity.x = 0.0;
                        here.velocity.y = 0.0;
                    }
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
            } elif here.velocity.length() > current_profile(here).leap_contact_speed
                and foe.health > 0 {
                contact = foe.pos.sub(here.pos);
                if abs(contact.x) < here.rule.width + 16.0
                    and abs(contact.y) < here.rule.width + 16.0
                    and abs(contact.z) < 56.0 {
                    profile = current_profile(here);
                    amount = event_damage(here, profile, 0);
                    dealt = strike(foe, amount, here, source=here.pos, tally=self.state, kick=0);
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
        rig = here.visual;
        if isinstance(rig, PlayerRig) {
            self.pose_body(here, rig, wish);
            return;
        }
        pose_name = "attack"
            if here.attack_flash > 0.0
            else ("run" if wish.length() > 0.0 else "stand");
        if here.pain_wait > 0.0 {
            pose_name = "pain";
        }
        if here.duck_wait > 0.0 and here.duck_animation {
            pose_name = "duck";
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
        if pose_name == "duck" {
            frames = here.duck_animation;
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
            } elif pose_name == "duck" {
                here.animation_time = duck_pose_time(here);
            } else {
                here.animation_time += self.dt * (
                    10.0 if pose_name == "walk" else (8.0 if pose_name != "stand" else 2.0)
                );
            }
            index = int(here.animation_time) % len(frames);
            if pose_name in ["attack", "pain", "duck"] {
                index = min(int(here.animation_time), len(frames) - 1);
            }
            here.visual.first = frames[index];
            here.visual.second = frames[min(index + 1, len(frames) - 1)]
                if pose_name in ["attack", "pain", "duck"]
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
