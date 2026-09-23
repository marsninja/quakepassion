"""Shared weapon simulation and graph-driven opponents."""
import math;
import from .particles { impact_spray, ParticleTick, rail_trail }
import from .navigation { ground_route, walk_edge }
import from .opponent_rule { OpponentRule }
import from .weapons { WeaponRule }
import from .world { World, Player }
import from .damage { Damage, blast_strength }
import from .inventory { Inventory, quantity, AdjustInventory }
import from .models { Visual }
import from .speakers { Speaker }
import from .signals { Signal, HasSignal, Fire }
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap }
import from ..physics.movement { MovePlayer, step_slide }
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
        attack_target: Vec3 = Vec3(),
        attack_speaker: Speaker | None = None,
        melee_speaker: Speaker | None = None,
        shot_random: int = 1,
        respawn_wait: float = 0.0,
        arena: bool = False,
        visual: Visual = Visual(),
        animation: list[int] = [],
        idle_animation: list[int] = [],
        attack_animation: list[int] = [],
        melee_animation: list[int] = [],
        alternate_melee_animation: list[int] = [],
        pain_animation: list[int] = [],
        death_animation: list[int] = [],
        pain_wait: float = 0.0,
        pain_cooldown: float = 0.0,
        pose_name: str = "",
        last_seen: Vec3 = Vec3(),
        last_seen_height: float = 22.0,
        alert: float = 0.0,
        steering: Vec3 = Vec3(),
        animation_time: float = 0.0,
        decision_wait: float = 0.0,
        support_wait: float = 0.0,
        pursuing: bool = False,
        route: list[Vec3] = [],
        route_wait: float = 0.0,
        route_target: Vec3 = Vec3(),
        boss_phase: int = 0,
        boss_time: float = 0.0;
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
        route_credit: float = 1.0;

    def random() -> float {
        self.random_state = (self.random_state * 48271) % 2147483647;
        return float(self.random_state) / 2147483647.0 * 2.0 - 1.0;
    }
}

# Finite ray versus actor box. A value of 1 means no hit before the endpoint.
def actor_fraction(
    start: Vec3, finish: Vec3, eye: Vec3, height: float, top_drop: float = 0.0
) -> float {
    lo = eye.sub(Vec3(x=16.0, y=16.0, z=height + 24.0));
    hi = eye.add(Vec3(x=16.0, y=16.0, z=32.0 - height - top_drop));
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

def damage_opponent(
    victim: Opponent,
    amount: int,
    inventory: Inventory | None = None,
    state: CombatState | None = None,
    bypass_armor: bool = False
) -> int {
    if victim.dormant or victim.rule.script == "chthon" {
        return 0;
    }
    damage = victim spawn Damage(amount=amount, bypass_armor=bypass_armor);
    if state is not None and damage.dealt > 0 {
        state.hit_flash = 0.15;
    }
    if damage.killed {
        if state is not None {
            state.kills += 1;
        }
        victim.activation spawn Fire(inventory=inventory);
        victim.visual.visible = bool(victim.death_animation);
        victim.attack_clock = -1.0;
        victim.attack_flash = 0.0;
        victim.pose_name = "death";
        victim.animation_time = 0.0;
        victim.respawn_wait = 3.0;
    } elif damage.dealt > 0 and victim.pain_cooldown <= 0.0 {
        victim.attack_clock = -1.0;
        victim.pain_wait = victim.rule.pain_duration;
        victim.pain_cooldown = victim.rule.pain_interval;
        victim.attack_flash = 0.0;
        victim.attack_wait = max(victim.attack_wait, victim.rule.pain_duration);
        victim.decision_wait = 0.0;
    }
    return damage.dealt;
}

walker Aim {
    has start: Vec3,
        finish: Vec3,
        height: float,
        fraction: float = 1.0,
        target: Opponent | None = None;

    can begin with World entry {
        visit [here->:HasOpponent:->];
    }

    can test_target with Opponent entry {
        if here.health <= 0 or here.dormant {
            return;
        }
        hit = actor_fraction(self.start, self.finish, here.pos, here.eye_height);
        if hit < self.fraction {
            self.fraction = hit;
            self.target = here;
        }
    }
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
        hostile: bool = False;
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
    state.cooldown = rule.interval;
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
            damage=rule.damage,
            splash=rule.splash,
            radius=rule.radius,
            gravity=rule.gravity,
            remaining=rule.fuse,
            effect=rule.effect,
            beam_damage=rule.beam_damage,
            beam_radius=rule.beam_radius,
            burst_damage=rule.burst_damage,
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
            amounts[victims.index(victim)] += rule.damage;
        }
        if (not hits or rule.piercing) and wall.fraction < 1.0 {
            impact_spray(world, player.pos.lerp(finish, wall.fraction), wall.normal);
            state.impact_model = wall.model;
            state.impacts.append(
                WeaponImpact(
                    model=wall.model,
                    amount=rule.damage,
                    origin=player.pos.lerp(finish, wall.fraction)
                )
            );
        }
    }
    for i in range(len(victims)) {
        damage_opponent(victims[i], amounts[i], player.inventory, state);
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
    grenade = Projectile(
        pos=player.pos,
        velocity=forward_from(player.yaw, player.pitch).scale(speed).add(Vec3(z=200.0)),
        damage=rule.damage,
        splash=rule.splash,
        radius=rule.radius,
        gravity=True,
        remaining=max(0.001, state.grenade_remaining),
        effect=rule.effect
    );
    state.shots += 1;
    state.flash = 0.08;
    state.cooldown = rule.interval;
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
    actors: list[Player] = [player];
    actors.extend(
        [
            enemy
            for enemy in [world->:HasOpponent:->][?:Opponent]
            if not enemy.dormant
        ]
    );
    for actor in actors {
        if actor is direct or actor.health <= 0 {
            continue;
        }
        height = actor.eye_height
            if isinstance(actor, Opponent)
            else collision.eye_height;
        center = actor.pos.sub(Vec3(z=height - 4.0));
        distance = center.sub(projectile.pos).length();
        if distance >= projectile.radius {
            continue;
        }
        sight = collision.trace_point(projectile.pos, center);
        if sight.start_solid or sight.fraction < 1.0 {
            continue;
        }
        strength = blast_strength(
            state.game, projectile.splash, projectile.radius, distance
        );
        if actor is player and not projectile.hostile {
            strength *= 0.5;
        }
        amount = int(strength);
        if isinstance(actor, Opponent) {
            damage_opponent(
                actor, amount, player.inventory, None if projectile.hostile else state
            );
        } else {
            actor spawn Damage(amount=amount);
        }
        if amount > 0 {
            actor.velocity = actor.velocity.add(
                center.sub(projectile.pos).normalized().scale(float(amount) * 4.0)
            );
            actor.grounded = False;
        }
    }
    state.impacts.append(
        WeaponImpact(
            origin=projectile.pos, splash=projectile.splash, radius=projectile.radius
        )
    );
}

# Energy tendrils use one ray per nearby target, piercing actors until world geometry.
def projectile_beams(
    world: World,
    projectile: Projectile,
    player: Player,
    collision: CollisionMap,
    state: CombatState
) {
    projectile.beams = [];
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
                    victim, projectile.beam_damage, player.inventory, state
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
        damage_opponent(victim, amount, player.inventory, state);
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
            self.player spawn Damage(amount=here.damage);
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
            damage_opponent(victim, here.damage, self.player.inventory, self.state);
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

def attack_times(enemy: Opponent) -> list[float] {
    if enemy.attack_melee and enemy.alternate_melee {
        return enemy.rule.alternate_melee_times;
    }
    return enemy.rule.melee_times
        if enemy.attack_melee and enemy.rule.melee_times
        else enemy.rule.attack_times;
}

def attack_duration(enemy: Opponent) -> float {
    if enemy.attack_melee and enemy.alternate_melee {
        return enemy.rule.alternate_melee_duration;
    }
    if enemy.attack_melee and enemy.rule.melee_times {
        return enemy.rule.melee_duration;
    }
    return enemy.rule.attack_duration + float(enemy.burst_count - 1) * 0.1;
}

def attack_event_count(enemy: Opponent) -> int {
    return len(attack_times(enemy)) + enemy.burst_count - 1;
}

def attack_event_time(enemy: Opponent) -> float {
    if enemy.burst_count > 1 {
        return enemy.rule.attack_times[0] + float(enemy.attack_event) * 0.1;
    }
    return attack_times(enemy)[enemy.attack_event];
}

def attack_pose_time(enemy: Opponent) -> float {
    clock = enemy.attack_clock * 10.0;
    if not enemy.attack_melee
        and enemy.rule.hold_frame >= 0
        and clock >= float(enemy.rule.hold_frame) {
        clock -= min(
            float(enemy.burst_count - 1), clock - float(enemy.rule.hold_frame)
        );
    }
    return clock;
}

def opponent_aim(enemy: Opponent, player: Player) -> Vec3 {
    target = enemy.attack_target
        if enemy.rule.lock_aim
        else player.pos.sub(player.velocity.scale(enemy.rule.aim_lag));
    direction = target.sub(enemy.pos).normalized();
    if enemy.rule.aim_spread > 0.0 or enemy.rule.aim_vertical > 0.0 {
        side = right_from(math.atan2(direction.y, direction.x));
        up = side.cross(direction).normalized();
        enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
        horizontal = float(enemy.shot_random) / 2147483647.0 * 2.0 - 1.0;
        enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
        vertical = float(enemy.shot_random) / 2147483647.0 * 2.0 - 1.0;
        direction = direction.add(side.scale(horizontal * enemy.rule.aim_spread)).add(
            up.scale(vertical * enemy.rule.aim_vertical)
        ).normalized();
    }
    return direction;
}

# Enemy spread has its own saved stream; effects and AI cannot alter player spread.
def opponent_shot(
    world: World, enemy: Opponent, player: Player, collision: CollisionMap
) {
    direction = opponent_aim(enemy, player);
    side = right_from(math.atan2(direction.y, direction.x));
    up = side.cross(direction).normalized();
    damage = 0;
    for i in range(enemy.rule.pellets) {
        shot = direction;
        if enemy.rule.spread > 0.0 {
            enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
            horizontal = float(enemy.shot_random) / 2147483647.0 * 2.0 - 1.0;
            enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
            vertical = float(enemy.shot_random) / 2147483647.0 * 2.0 - 1.0;
            shot = shot.add(side.scale(horizontal * enemy.rule.spread)).add(
                up.scale(
                    vertical
                        * (
                            enemy.rule.vertical_spread
                                if enemy.rule.vertical_spread >= 0.0
                                else enemy.rule.spread
                        )
                )
            );
        }
        finish = enemy.pos.add(shot.normalized().scale(8192.0));
        wall = collision.trace_point(enemy.pos, finish);
        if enemy.rule.rail {
            rail_trail(world, enemy.pos, enemy.pos.lerp(finish, wall.fraction));
        }
        hit = actor_fraction(
            enemy.pos, finish, player.pos, collision.eye_height, collision.top_drop
        );
        if hit < wall.fraction {
            damage += 6 if enemy.arena else enemy.rule.damage;
        } elif wall.fraction < 1.0 and not wall.start_solid {
            impact_spray(world, enemy.pos.lerp(finish, wall.fraction), wall.normal);
        }
    }
    if damage > 0 {
        player spawn Damage(amount=damage);
    }
}

# Integrate authored charge distances across 10 Hz animation frames, using the
# same stair/slide collision as walking. Keep a body-width gap to the player.
def attack_charge(enemy: Opponent, player: Player, collision: CollisionMap, dt: float) {
    steps = enemy.rule.melee_steps
        if enemy.attack_melee and enemy.rule.melee_times
        else enemy.rule.attack_steps;
    if enemy.attack_melee and enemy.alternate_melee {
        steps = enemy.rule.alternate_melee_steps;
    }
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
    world: World, enemy: Opponent, player: Player, collision: CollisionMap, dt: float
) {
    if enemy.attack_clock < 0.0 or enemy.health <= 0 or enemy.dormant {
        return;
    }
    attack_charge(enemy, player, collision, dt);
    speaker = enemy.melee_speaker if enemy.attack_melee else enemy.attack_speaker;
    sound_times = enemy.rule.attack_sound_times;
    if enemy.attack_melee {
        sound_times = enemy.rule.alternate_melee_sound_times
            if enemy.alternate_melee
            else enemy.rule.melee_sound_times;
    }
    if speaker is not None and dt > 0.0 {
        speaker.origin = enemy.pos.add(Vec3());
        for at in sound_times {
            if (
                enemy.attack_clock + 0.000001 < at
                and enemy.attack_clock + dt + 0.000001 >= at
            )
                or (at == 0.0 and enemy.attack_clock == 0.0) {
                speaker.requests += 1;
            }
        }
    }
    enemy.attack_clock += dt;
    while enemy.attack_event < attack_event_count(enemy)
        and attack_event_time(enemy) <= enemy.attack_clock + 0.000001 {
        enemy.attack_event += 1;
        delta = player.pos.sub(enemy.pos);
        distance = delta.length();
        sight = collision.trace_point(enemy.pos, player.pos);
        if player.health <= 0
            or (
                (not enemy.rule.lock_aim or enemy.attack_melee)
                and (
                    sight.start_solid
                    or sight.fraction < 1.0
                    or distance > enemy.rule.attack_range
                )
            ) {
            continue;
        }
        if enemy.attack_melee {
            if distance <= enemy.rule.melee_range {
                amount = enemy.rule.melee;
                maximum = enemy.rule.melee_max;
                if enemy.alternate_melee and enemy.rule.alternate_melee_damage >= 0 {
                    amount = enemy.rule.alternate_melee_damage;
                    maximum = enemy.rule.alternate_melee_max;
                }
                if enemy.rule.melee_random_scale > 0.0 {
                    total = 0.0;
                    for sample in range(3) {
                        enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
                        total += float(enemy.shot_random) / 2147483647.0;
                    }
                    amount = int(total * enemy.rule.melee_random_scale);
                } elif maximum > amount {
                    enemy.shot_random = (enemy.shot_random * 48271) % 2147483647;
                    amount += enemy.shot_random % (maximum - amount + 1);
                }
                result = player spawn Damage(amount=amount);
                if result.dealt > 0 and enemy.rule.melee_knockback > 0.0 {
                    player.velocity = player.velocity.add(
                        delta.normalized().scale(enemy.rule.melee_knockback)
                    );
                    if player.velocity.z > 0.0 {
                        player.grounded = False;
                    }
                }
            }
        } elif enemy.rule.missile_speed > 0.0 {
            direction = opponent_aim(enemy, player);
            shot_index = enemy.attack_event - 1;
            if shot_index < len(enemy.rule.missile_yaw) {
                angle = enemy.rule.missile_yaw[shot_index] * math.pi / 180.0;
                direction = Vec3(
                    x=direction.x * math.cos(angle) - direction.y * math.sin(angle),
                    y=direction.x * math.sin(angle) + direction.y * math.cos(angle),
                    z=direction.z
                );
            }
            velocity = direction.scale(enemy.rule.missile_speed);
            if enemy.rule.gravity {
                velocity.z = 200.0;
            }
            world +>:HasProjectile:+> Projectile(
                pos=enemy.pos,
                velocity=velocity,
                damage=enemy.rule.damage,
                hostile=True,
                effect=enemy.rule.missile_effect,
                gravity=enemy.rule.gravity,
                splash=enemy.rule.splash,
                radius=enemy.rule.radius,
                remaining=2.5 if enemy.rule.gravity else 5.0
            );
        } elif enemy.rule.melee == 0 or enemy.rule.melee_times {
            opponent_shot(world, enemy, player, collision);
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
    world: World, enemy: Opponent, player: Player, collision: CollisionMap, dt: float
) {
    restart = enemy.rule.melee_repeat_start
        if enemy.attack_melee
        else enemy.rule.repeat_start;
    boundary = enemy.rule.melee_repeat_end
        if enemy.attack_melee
        else enemy.rule.repeat_end;
    chance = enemy.rule.melee_repeat_chance
        if enemy.attack_melee
        else enemy.rule.repeat_chance;
    if restart < 0.0 or boundary <= restart or boundary >= attack_duration(enemy) {
        advance_attack_segment(world, enemy, player, collision, dt);
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
        advance_attack_segment(world, enemy, player, collision, step);
        remaining = max(0.0, remaining - step);
        if crossing and enemy.attack_clock >= 0.0 and player.health > 0 {
            distance = player.pos.sub(enemy.pos).length();
            sight = collision.trace_point(enemy.pos, player.pos);
            valid = distance <= enemy.rule.melee_range
                if enemy.attack_melee
                else distance > enemy.rule.melee_range;
            if valid
                and distance <= enemy.rule.attack_range
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
                    advance_attack_segment(world, enemy, player, collision, 0.0);
                }
            }
        }
    }
}

walker CombatTick {
    has player: Player,
        collision: CollisionMap,
        state: CombatState,
        dt: float,
        active: bool = True,
        world: World | None = None,
        body_collision: CollisionMap | None = None;

    can begin with World entry {
        self.world = here;
        self.state.route_credit = min(
            1.0, self.state.route_credit + max(0.0, self.dt) * 8.0
        );
        here spawn ParticleTick(dt=self.dt);
        self.state.cooldown = max(0.0, self.state.cooldown - self.dt);
        self.state.flash = max(0.0, self.state.flash - self.dt);
        self.state.hit_flash = max(0.0, self.state.hit_flash - self.dt);
        if self.active and self.player.health > 0 {
            visit [here->:HasOpponent:->];
        }
    }

    can think with Opponent entry {
        if here.rule.script == "chthon" {
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
                self.player spawn Damage(amount=100000, bypass_armor=True);
            }
        }
        if here.health <= 0 {
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
            if not here.arena {
                return;
            }
            here.respawn_wait = max(0.0, here.respawn_wait - self.dt);
            if here.respawn_wait > 0.0
                or here.home.sub(self.player.pos).length() < 80.0 {
                return;
            }
            here.health = here.max_health;
            here.pos = here.home;
            here.route = [];
            here.route_wait = 0.0;
            here.velocity = Vec3();
            here.visual.visible = True;
            here.attack_wait = 1.0;
        }
        if self.body_collision is None
            or self.body_collision.eye_height != here.eye_height {
            self.body_collision = self.collision.for_body(here.eye_height);
        }
        body_collision = self.body_collision;
        delta = self.player.pos.sub(here.pos);
        distance = delta.length();
        here.pain_wait = max(0.0, here.pain_wait - self.dt);
        here.pain_cooldown = max(0.0, here.pain_cooldown - self.dt);
        here.attack_wait = max(0.0, here.attack_wait - self.dt);
        here.attack_flash = max(0.0, here.attack_flash - self.dt);
        here.alert = max(0.0, here.alert - self.dt);
        here.route_wait = max(0.0, here.route_wait - self.dt);
        here.decision_wait -= self.dt;
        if here.decision_wait <= 0.0 {
            here.decision_wait = 0.1;
            here.pursuing = False;
            if distance < 1500.0 {
                sight = self.collision.trace_point(here.pos, self.player.pos);
                here.pursuing = not sight.start_solid and sight.fraction == 1.0;
                if here.pursuing {
                    here.last_seen = self.player.pos;
                    here.last_seen_height = self.collision.eye_height;
                    here.alert = 8.0;
                }
                # Attack only with a fresh sight query, never cached visibility.
                if here.pursuing
                    and here.attack_wait <= 0.0
                    and here.pain_wait <= 0.0
                    and here.attack_clock < 0.0 {
                    if distance <= here.rule.attack_range
                        and (
                            distance >= here.rule.ranged_min
                            or distance <= here.rule.melee_range
                        ) {
                        here.attack_melee = (
                            here.rule.melee > 0 or here.rule.melee_random_scale > 0.0
                        )
                            and distance <= here.rule.melee_range;
                        here.attack_target = self.player.pos.add(Vec3());
                        here.attack_clock = 0.0;
                        here.attack_event = 0;
                        here.burst_count = 1;
                        here.alternate_melee = False;
                        if here.attack_melee and here.rule.alternate_melee_times {
                            here.shot_random = (here.shot_random * 48271) % 2147483647;
                            here.alternate_melee = here.shot_random > 1073741823;
                        }
                        if here.rule.burst_max > 1 and not here.attack_melee {
                            here.shot_random = (here.shot_random * 48271) % 2147483647;
                            here.burst_count = here.rule.burst_min
                                + here.shot_random
                                    % (here.rule.burst_max - here.rule.burst_min + 1);
                        }
                        here.attack_wait = max(
                            here.rule.interval, attack_duration(here)
                        );
                        here.attack_flash = attack_duration(here);
                    }
                }
            }
            here.steering = Vec3();
            destination = here.last_seen;
            if here.grounded and here.alert > 0.0 and here.attack_clock < 0.0 {
                origin = here.pos.sub(Vec3(z=here.eye_height));
                target = destination.sub(Vec3(z=here.last_seen_height));
                if here.route_target.sub(target).length() > 48.0 {
                    here.route = [];
                }
                while here.route and here.route[0].sub(origin).length() < 16.0 {
                    here.route.pop(0);
                }
                if here.route
                    and walk_edge(body_collision, origin, here.route[0]) is None {
                    here.route = [];
                }
                if not here.route
                    and here.route_wait <= 0.0
                    and self.state.route_credit >= 1.0 {
                    self.state.route_credit -= 1.0;
                    here.route_wait = 1.0;
                    here.route_target = target;
                    here.route = ground_route(body_collision, origin, target);
                }
                if here.route {
                    destination = here.route[0].add(Vec3(z=here.eye_height));
                }
            }
            goal = destination.sub(here.pos);
            if here.alert > 0.0
                and goal.length()
                    > (
                        here.rule.stop_range
                            if here.pursuing and len(here.route) <= 1
                            else 12.0
                    ) {
                direction = Vec3(x=goal.x, y=goal.y).normalized();
                # Local separation is evaluated with steering, not every physics tick.
                if self.world is not None {
                    for neighbor in [self.world->:HasOpponent:->][?:Opponent] {
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
                best = -1.0;
                for angle in [0.0, 0.785398, -0.785398, 1.570796, -1.570796] {
                    candidate = Vec3(
                        x=direction.x * math.cos(angle) - direction.y * math.sin(angle),
                        y=direction.x * math.sin(angle) + direction.y * math.cos(angle)
                    );
                    probe = body_collision.trace(
                        here.pos.sub(Vec3(z=here.eye_height)),
                        here.pos.sub(Vec3(z=here.eye_height)).add(candidate.scale(48.0))
                    );
                    if here.grounded {
                        origin = here.pos.sub(Vec3(z=here.eye_height));
                        reachable = walk_edge(
                            body_collision,
                            origin,
                            origin.add(candidate.scale(48.0)),
                            match_height=False
                        );
                        if reachable is None {
                            continue;
                        }
                        probe.fraction = 1.0;
                    }
                    score = probe.fraction + 0.15 * math.cos(angle);
                    if not probe.start_solid
                        and probe.fraction > 0.3
                        and score > best {
                        best = score;
                        here.steering = candidate;
                    }
                }
            }
        }
        if self.world is not None {
            advance_attack(self.world, here, self.player, self.collision, self.dt);
        }
        wish = Vec3()
            if here.pain_wait > 0.0 or here.attack_flash > 0.0
            else here.steering;
        if here.alert > 0.0 {
            goal = here.last_seen.sub(here.pos);
            target_yaw = math.atan2(goal.y, goal.x);
            turn = math.atan2(
                math.sin(target_yaw - here.yaw), math.cos(target_yaw - here.yaw)
            );
            here.yaw += max(-6.0 * self.dt, min(6.0 * self.dt, turn));
        }
        here.support_wait -= self.dt;
        # Settled actors probe support at 20 Hz; motion and gravity remain 120 Hz.
        if not here.grounded
            or here.velocity.length() > 0.000001
            or wish.length() > 0.0
            or here.support_wait <= 0.0 {
            here spawn MovePlayer(collision=body_collision, wish=wish, dt=self.dt);
            here.support_wait = 0.05;
        }
        pose_name = "attack"
            if here.attack_flash > 0.0
            else ("run" if wish.length() > 0.0 else "stand");
        if here.pain_wait > 0.0 {
            pose_name = "pain";
        }
        frames = here.attack_animation
            if pose_name == "attack"
            else (here.animation if pose_name == "run" else here.idle_animation);
        if pose_name == "attack" and here.attack_melee and here.melee_animation {
            frames = here.alternate_melee_animation
                if here.alternate_melee
                else here.melee_animation;
        }
        if pose_name == "pain" {
            frames = here.pain_animation;
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
                here.animation_time = max(0.0, here.rule.pain_duration - here.pain_wait)
                    * 10.0;
            } else {
                here.animation_time += self.dt * (8.0 if pose_name != "stand" else 2.0);
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
    }
}
