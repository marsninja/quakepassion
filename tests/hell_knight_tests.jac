import math;
import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    CombatState,
    CombatTick,
    damage_opponent,
    choose_attack,
    begin_attack,
    current_profile
}
import from engine.physics.collision { CollisionMap }
import from engine.world.opponent_rule { OpponentRule }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }

test "hell knight fires six distinct directions after windup" {
    rule = enemy_rule("q1", "monster_hell_knight");
    assert rule is not None;
    # Attack the moment it may, to time the sequence itself.
    rule.near_chance = 1.0;
    rule.mid_chance = 1.0;
    world = World();
    level = Level(name="fan");
    player = Player(pos=Vec3(x=500.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert not [world->:HasProjectile:->];
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.6
    );
    shots = [world->:HasProjectile:->][?:Projectile];
    assert len(shots) == 6;
    for i in range(6) {
        angle = math.atan2(shots[i].velocity.y, shots[i].velocity.x) * 180.0 / math.pi;
        assert abs(angle - (-12.0 + float(i) * 6.0)) < 0.001;
        assert shots[i].damage == 9 and shots[i].effect == "q1_knightspike";
        assert abs(shots[i].velocity.length() - 300.0) < 0.001;
    }
}

test "hell knight saves the volley cursor and vertical scatter stream" {
    rule = enemy_rule("q1", "monster_hell_knight");
    assert rule is not None;
    # Attack the moment it may, to time the sequence itself.
    rule.near_chance = 1.0;
    rule.mid_chance = 1.0;
    world = World();
    level = Level(name="fan");
    level.bsp.game = "q1";
    player = Player(pos=Vec3(x=500.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.7
    );
    assert len([world->:HasProjectile:->]) == 3;
    saved = snapshot(world, level, player, state);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.3
    );
    z = [world->:HasProjectile:->][?:Projectile][-1].velocity.z;
    restore(world, level, player, state, saved);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.3
    );
    assert len([world->:HasProjectile:->]) == 6;
    assert abs([world->:HasProjectile:->][?:Projectile][-1].velocity.z - z) < 0.001;
}

test "hell knight sword hits can be escaped and pain cancels pending spikes" {
    rule = enemy_rule("q1", "monster_hell_knight");
    assert rule is not None;
    # Attack the moment it may, to time the sequence itself.
    rule.near_chance = 1.0;
    rule.mid_chance = 1.0;
    world = World();
    level = Level(name="sword");
    player = Player(pos=Vec3(x=50.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert enemy.attack_melee and player.health >= 92 and player.health < 100;
    health = player.health;
    player.pos.x = 500.0;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert player.health == health and not [world->:HasProjectile:->];
    enemy.attack_clock = -1.0;
    enemy.attack_wait = 0.0;
    enemy.decision_wait = 0.0;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    damage_opponent(enemy, 1);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert not [world->:HasProjectile:->];
}

def q1_rule(kind: str) -> OpponentRule {
    rule = enemy_rule("q1", kind);
    assert rule is not None;
    return rule;
}

def knight_floor() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-2000.0, y=-2000.0, z=-64.0),
        Vec3(x=2000.0, y=2000.0, z=0.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    collision.reindex();
    return collision;
}

test "hell knights share one turn of slice, smash and wide swing" {
    first = Opponent(rule=q1_rule("monster_hell_knight"));
    second = Opponent(rule=q1_rule("monster_hell_knight"));
    turns: dict[str, int] = {};
    names: list[str] = [];
    for knight in [first, second, first, second] {
        chosen = choose_attack(knight, 90.0, turns);
        names.append(knight.profiles[chosen].name);
    }
    # hknight_melee's global hknight_type: 1 slice, 2 smash, 3 watk, again.
    assert names == ["slice", "smash", "watk", "slice"];
    # Out of melee range (CheckAttack's RANGE_MELEE is 120) it casts, and the
    # run-cycle charge is never an attack decision.
    assert first.profiles[choose_attack(first, 300.0, turns)].name == "magic";
    level = Level(name="turns");
    level.bsp.game = "q1";
    state = CombatState(game="q1", turns=turns);
    saved = snapshot(World(), level, Player(), state);
    state.turns = {};
    restore(World(), level, Player(), state, saved);
    assert state.turns == {"hknight_type": 1};
}

test "hell knight charges from its run cycle only level with the target" {
    collision = knight_floor();
    world = World();
    player = Player(pos=Vec3(x=300.0, z=22.0));
    # No spell first: in range CheckAttack casts one time in five.
    caster = q1_rule("monster_hell_knight");
    caster.near_chance = 0.0;
    knight = Opponent(
        rule=caster,
        pos=Vec3(z=22.0),
        grounded=True,
        attack_wait=0.0,
        alert=8.0,
        health=250,
        animation=list(range(8)),
        walk_animation=list(range(20))
    );
    world +>:HasOpponent:+> knight;
    state = CombatState(game="q1");
    started = "";
    for tick in range(60) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
        if knight.attack_clock >= 0.0 and not started {
            started = current_profile(knight).name;
        }
    }
    # CheckForCharge's SUB_AttackFinished(2) holds off the next attack.
    assert started == "charge" and knight.attack_wait > 1.0;
    # char_a1-5 close in by 93 units in half a second.
    assert knight.pos.x > 60.0;
    # Twenty-one units higher, the run cycle starts no charge.
    high = Opponent(
        rule=q1_rule("monster_hell_knight"),
        pos=Vec3(z=22.0),
        grounded=True,
        alert=8.0,
        pursuing=True,
        attack_wait=0.0,
        health=250,
        animation=list(range(8))
    );
    raised = Player(pos=Vec3(x=300.0, z=43.0));
    tick = CombatTick(player=raised, collision=collision, state=state, dt=0.01);
    tick.run_start(high, raised);
    assert high.attack_clock < 0.0;
    raised.pos.z = 42.0;
    tick.run_start(high, raised);
    assert current_profile(high).name == "charge";
}

test "a knight swings close by and slashes past from further out" {
    knight = Opponent(rule=q1_rule("monster_knight"));
    assert knight.profiles == [] and choose_attack(knight, 60.0) == 0;
    assert knight.profiles[choose_attack(knight, 100.0)].name == "runattack";
    assert choose_attack(knight, 130.0) == -1;
    # knight_runatk: 20-unit strides aimed 30 left of the target bring it up
    # beside the player, whose box stops it, slashing (ai_melee_side).
    collision = knight_floor();
    world = World();
    player = Player(pos=Vec3(x=100.0, z=22.0));
    runner = Opponent(
        rule=q1_rule("monster_knight"),
        pos=Vec3(z=22.0),
        grounded=True,
        alert=8.0,
        health=75
    );
    world +>:HasOpponent:+> runner;
    begin_attack(runner, 1, player.pos);
    state = CombatState(game="q1");
    for tick in range(110) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    }
    assert runner.pos.y > 10.0 and player.health < 100;
    apart = runner.pos.sub(player.pos);
    assert abs(apart.x) >= 32.0 or abs(apart.y) >= 32.0;
}
