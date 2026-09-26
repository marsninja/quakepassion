import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    CombatState,
    CombatTick,
    attack_pose_time,
    attack_duration,
    damage_opponent,
    muzzle_origin,
    muzzle_flash_age,
    launch_missile
}
import from engine.world.opponent_rule { AttackProfile, rule_profiles }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3, forward_from, right_from }

test "Q2 light soldiers wind up before firing a spread blaster bolt" {
    rule = enemy_rule("q2", "monster_soldier_light");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=200.0));
    state = CombatState();
    collision = CollisionMap();
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert not [world->:HasProjectile:->];
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    bolts = [world->:HasProjectile:->][?:Projectile];
    assert len(bolts) == 1 and bolts[0].damage == 5 and bolts[0].hostile;
    assert abs(bolts[0].velocity.length() - 600.0) < 0.001;
    assert abs(bolts[0].velocity.y) > 0.001;
    assert player.health == 100;
}

test "Q2 shotgun soldiers use twelve pellets with distinct horizontal and vertical spread" {
    rule = enemy_rule("q2", "monster_soldier");
    assert rule is not None;
    assert rule.pellets == 12 and rule.damage == 2 and rule.missile_speed == 0.0;
    assert rule.spread == 2.0 * rule.vertical_spread;
    world = World();
    player = Player(pos=Vec3(x=40.0));
    state = CombatState();
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.2
    );
    assert player.health >= 76 and player.health < 100;
    assert not [world->:HasProjectile:->];
}

test "Q2 machinegun burst holds its pose and survives save restore without duplicate shots" {
    rule = enemy_rule("q2", "monster_soldier_ss");
    assert rule is not None;
    world = World();
    level = Level(name="burst");
    level.bsp.game = "q2";
    player = Player(pos=Vec3(x=200.0), god_mode=True);
    state = CombatState();
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.2
    );
    assert enemy.attack_event == 1
        and enemy.burst_count >= 4
        and enemy.burst_count <= 11;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert enemy.attack_event == 2 and abs(attack_pose_time(enemy) - 2.0) < 0.00001;
    saved = snapshot(world, level, player, state);
    count = enemy.burst_count;
    stream = enemy.shot_random;
    enemy.burst_count = 1;
    enemy.shot_random = 1;
    restore(world, level, player, state, saved);
    assert enemy.burst_count == count
        and enemy.shot_random == stream
        and enemy.attack_event == 2;
    enemy.decision_wait = 10.0;
    for i in range(30) {
        world spawn CombatTick(
            player=player, collision=level.collision, state=state, dt=0.1
        );
    }
    assert enemy.attack_event == count and enemy.attack_clock < 0.0;
}

test "infantry gun has a longer windup and damage interrupts held bursts" {
    rule = enemy_rule("q2", "monster_infantry");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=200.0), god_mode=True);
    state = CombatState();
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.9
    );
    assert enemy.attack_event == 0;
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.1
    );
    assert enemy.attack_event == 1
        and enemy.burst_count >= 4
        and enemy.burst_count <= 19;
    assert abs(attack_pose_time(enemy) - 10.0) < 0.00001;
    damage_opponent(enemy, 1);
    assert enemy.attack_clock < 0.0;
    enemy.decision_wait = 10.0;
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.4
    );
    assert enemy.attack_event == 1;
}

"""Where a monster's `index`th shot should leave, from its origin."""
def expected_muzzle(enemy: Opponent, offset: Vec3) -> Vec3 {
    origin = enemy.pos.sub(Vec3(z=enemy.eye_height));
    return origin.add(forward_from(enemy.yaw, 0.0).scale(offset.x))
        .add(right_from(enemy.yaw).scale(offset.y))
        .add(Vec3(z=offset.z));
}

test "monster shots leave their muzzles and light a flash there" {
    rule = enemy_rule("q2", "monster_soldier_light");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=200.0));
    state = CombatState();
    collision = CollisionMap();
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    for step in range(2) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    }
    bolts = [world->:HasProjectile:->][?:Projectile];
    assert len(bolts) == 1;
    # MZ2_SOLDIER_BLASTER_1: 10.6, 7.7, 7.8 scaled by 1.2.
    muzzle = expected_muzzle(enemy, Vec3(x=12.72, y=9.24, z=9.36));
    assert bolts[0].pos.sub(muzzle).length() < 0.01;
    assert muzzle_flash_age(enemy) >= 0.0;
    assert enemy.flash_origin.sub(muzzle).length() < 0.01;
    assert enemy.flash_color.x == 1.0 and enemy.flash_color.y == 1.0 and enemy.flash_color.z == 0.0;
    # The flash is gone a tenth of a second later.
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.1);
    assert muzzle_flash_age(enemy) < 0.0;
}

test "a volley fires each rocket from its own tube and walls stop muzzles short" {
    rule = enemy_rule("q2", "monster_boss2");
    assert rule is not None;
    enemy = Opponent(rule=rule, pos=Vec3(z=22.0), yaw=0.5);
    profile = [profile for profile in rule_profiles(rule) if profile.name == "rockets"][0];
    assert profile.volley and len(profile.muzzles) == 4;
    world = World();
    player = Player(pos=Vec3(x=400.0, z=22.0));
    for shot in range(4) {
        launch_missile(
            world, enemy, Vec3(x=1.0), profile, player, muzzle_origin(enemy, profile, shot)
        );
    }
    rockets = [world->:HasProjectile:->][?:Projectile];
    assert len(rockets) == 4;
    for shot in range(4) {
        assert rockets[shot].pos.sub(expected_muzzle(enemy, profile.muzzles[shot])).length() < 0.01;
    }
    # Q1 enforcer_fire: a wall between the origin and the muzzle holds the shot.
    enforcer = enemy_rule("q1", "monster_enforcer");
    assert enforcer is not None;
    guard = Opponent(rule=enforcer, pos=Vec3(z=22.0));
    laser = rule_profiles(enforcer)[0];
    open_start = muzzle_origin(guard, laser, 0, CollisionMap());
    assert open_start.sub(expected_muzzle(guard, Vec3(x=30.0, y=8.5, z=16.0))).length() < 0.01;
    walled = CollisionMap();
    walled.add_box(Vec3(x=20.0, y=-100.0, z=-100.0), Vec3(x=24.0, y=100.0, z=100.0), Vec3(), Vec3(), Vec3());
    blocked = muzzle_origin(guard, laser, 0, walled);
    assert blocked.x < 20.0 and blocked.x > 0.0;
    # Without muzzles a shot still leaves the eye.
    assert muzzle_origin(guard, AttackProfile(), 0, walled).sub(guard.pos).length() < 0.001;
}
