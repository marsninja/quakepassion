import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    CombatState,
    CombatTick,
    ProjectileTick,
    damage_opponent,
    choose_attack
}
import from engine.world.particles { HasTrail, ShotTrail }
import from engine.world.speakers { Speaker, HasSpeaker }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

def floor_map() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-2000.0, y=-2000.0, z=-10.0),
        Vec3(x=2000.0, y=2000.0, z=0.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    return collision;
}

test "scrag flies toward the player without falling and fires two spikes" {
    rule = enemy_rule("q1", "monster_wizard");
    assert rule is not None and rule.movement == "fly";
    world = World();
    collision = floor_map();
    player = Player(pos=Vec3(x=700.0, z=22.0));
    enemy = Opponent(
        rule=rule, pos=Vec3(z=200.0), walk_speed=rule.speed, attack_wait=5.0
    );
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    for i in range(120) {
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=0.01
        );
    }
    assert enemy.pos.x > 50.0 , str(enemy.pos.x);
    assert enemy.pos.z > 60.0 and enemy.pos.z < 200.0 , str(enemy.pos.z);
    assert not enemy.grounded;
    enemy.attack_wait = 0.0;
    enemy.decision_wait = 0.0;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.35);
    assert len([world->:HasProjectile:->]) == 1;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.5);
    shots = [world->:HasProjectile:->][?:Projectile];
    assert len(shots) == 2
        and shots[0].damage == 9
        and shots[0].effect == "q1_wizspike";
}

test "fiend leaps beyond claw range and damages on contact" {
    rule = enemy_rule("q1", "monster_demon1");
    assert rule is not None;
    world = World();
    collision = floor_map();
    player = Player(pos=Vec3(x=180.0, z=22.0));
    enemy = Opponent(
        rule=rule, pos=Vec3(z=22.01), grounded=True, attack_wait=0.0, shot_random=5
    );
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    assert choose_attack(enemy, 180.0) == 1;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.05);
    assert enemy.attack_profile == 1 and not enemy.leaping;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.3);
    assert enemy.leaping and enemy.velocity.x > 500.0 and not enemy.grounded;
    for i in range(40) {
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=0.01
        );
        if player.health < 100 {
            break;
        }
    }
    assert player.health >= 50 and player.health <= 60 , str(player.health);
    assert not enemy.leaping and player.velocity.x > 0.0;
}

test "fiend claws when close and leap is not chosen inside claw range" {
    rule = enemy_rule("q1", "monster_demon1");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=70.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    assert choose_attack(enemy, 70.0) == 0;
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.5
    );
    assert enemy.attack_melee and player.health >= 85 and player.health <= 90;
}

test "shambler lightning is an instant beam blocked by walls and blasts hurt it half" {
    rule = enemy_rule("q1", "monster_shalrath");
    assert rule is not None;
    rule = enemy_rule("q1", "monster_shambler");
    assert rule is not None and rule.blast_scale == 0.5;
    for blocked in [False, True] {
        world = World();
        collision = CollisionMap();
        player = Player(pos=Vec3(x=300.0));
        enemy = Opponent(rule=rule, attack_wait=0.0);
        world +>:HasOpponent:+> enemy;
        state = CombatState(game="q1");
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=0.65
        );
        assert enemy.attack_profile == 3 and player.health == 100;
        if blocked {
            collision.add_box(
                Vec3(x=150.0, y=-200.0, z=-200.0),
                Vec3(x=151.0, y=200.0, z=200.0),
                Vec3(),
                Vec3(),
                Vec3()
            );
        }
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.3);
        trails = [world->:HasTrail:->][?:ShotTrail];
        if blocked {
            assert player.health == 100 and not trails;
        } else {
            assert player.health == 70 , str(player.health);
            assert len(trails) == 3 and trails[0].kind == "lightning";
        }
    }
}

test "shambler close attacks are chosen by weight and all three hit in reach" {
    rule = enemy_rule("q1", "monster_shambler");
    assert rule is not None;
    seen: list[int] = [];
    for seed in range(1, 40) {
        enemy = Opponent(rule=rule, shot_random=seed * 104729);
        chosen = choose_attack(enemy, 60.0);
        assert chosen >= 0 and chosen <= 2;
        if chosen not in seen {
            seen.append(chosen);
        }
    }
    assert len(seen) == 3;
    world = World();
    player = Player(pos=Vec3(x=60.0));
    enemy = Opponent(rule=rule, attack_wait=0.0, shot_random=7);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=1.25
    );
    assert player.health < 100 and enemy.attack_melee;
}

test "zombie resets health on pain ignores grazes and goes down from heavy hits" {
    rule = enemy_rule("q1", "monster_zombie");
    assert rule is not None;
    world = World();
    level = Level(name="zombie");
    level.bsp.game = "q1";
    player = Player(pos=Vec3(x=300.0));
    enemy = Opponent(rule=rule, health=60, max_health=60);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    damage_opponent(enemy, 5);
    assert enemy.health == 60 and enemy.pain_wait == 0.0;
    damage_opponent(enemy, 15);
    assert enemy.health == 60 and enemy.pain_wait > 0.0 and not enemy.pain_down;
    assert enemy.pain_variant >= 1 and enemy.pain_variant <= 4;
    enemy.pain_wait = 0.0;
    enemy.pain_cooldown = 0.0;
    damage_opponent(enemy, 30);
    assert enemy.pain_down and abs(enemy.pain_wait - 8.0) < 0.001;
    saved = snapshot(world, level, player, state);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.5
    );
    assert enemy.pain_down and abs(enemy.pain_wait - 7.5) < 0.001;
    restore(world, level, player, state, saved);
    assert enemy.pain_down and abs(enemy.pain_wait - 8.0) < 0.001;
    damage_opponent(enemy, 60);
    assert enemy.health == 0 and not enemy.visual.visible;
}

test "zombie throws flesh with gravity from one of three sequences" {
    rule = enemy_rule("q1", "monster_zombie");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=400.0));
    enemy = Opponent(rule=rule, attack_wait=0.0, shot_random=3);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=1.05
    );
    assert enemy.attack_profile >= 0 and enemy.attack_profile <= 2;
    assert not [world->:HasProjectile:->];
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.35
    );
    shots = [world->:HasProjectile:->][?:Projectile];
    assert len(shots) == 1 and shots[0].gravity and shots[0].damage == 10;
    assert abs(shots[0].velocity.z - 200.0) < 0.001;
}

test "vore pod homes toward the player and survives a save" {
    rule = enemy_rule("q1", "monster_shalrath");
    assert rule is not None;
    world = World();
    level = Level(name="vore");
    level.bsp.game = "q1";
    player = Player(pos=Vec3(x=600.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.85
    );
    pods = [world->:HasProjectile:->][?:Projectile];
    assert len(pods) == 1 and pods[0].homing == 250.0 and pods[0].splash == 40;
    player.pos = Vec3(x=300.0, y=300.0);
    world spawn ProjectileTick(
        player=player, collision=level.collision, state=state, dt=0.25
    );
    assert pods[0].velocity.y > 100.0 , str(pods[0].velocity.y);
    assert abs(pods[0].velocity.length() - 250.0) < 0.01;
    saved = snapshot(world, level, player, state);
    restore(world, level, player, state, saved);
    restored = [world->:HasProjectile:->][?:Projectile];
    assert len(restored) == 1 and restored[0].homing == 250.0 and restored[0].hostile;
    for i in range(20) {
        world spawn ProjectileTick(
            player=player, collision=level.collision, state=state, dt=0.1
        );
    }
    assert player.health < 100 and not [world->:HasProjectile:->];
}

test "spawn hops at the player and explodes when killed" {
    rule = enemy_rule("q1", "monster_tarbaby");
    assert rule is not None;
    world = World();
    collision = floor_map();
    player = Player(pos=Vec3(x=150.0, z=22.0));
    enemy = Opponent(
        rule=rule, pos=Vec3(z=22.01), grounded=True, attack_wait=0.0, health=80
    );
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.45);
    assert enemy.leaping and enemy.velocity.z >= 200.0 and enemy.velocity.z <= 350.0;
    other = Opponent(rule=rule, pos=Vec3(x=60.0, z=22.01), grounded=True, health=80);
    world +>:HasOpponent:+> other;
    damage_opponent(enemy, 80);
    assert enemy.health == 0 and enemy.pending_explosion and not enemy.visual.visible;
    player.pos = Vec3(x=40.0, z=22.0);
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert not enemy.pending_explosion;
    assert player.health < 100 , str(player.health);
    assert other.health < 80 , str(other.health);
}

test "rotfish only swims while submerged and bites three times per pass" {
    rule = enemy_rule("q1", "monster_fish");
    assert rule is not None and rule.movement == "swim";
    world = World();
    collision = floor_map();
    player = Player(pos=Vec3(x=300.0, z=40.0));
    enemy = Opponent(
        rule=rule, pos=Vec3(z=60.0), walk_speed=rule.speed, attack_wait=5.0
    );
    enemy.water_depth = 3;
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    for i in range(60) {
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=0.01
        );
    }
    assert enemy.pos.x > 30.0 and enemy.pos.z > 40.0 , str(enemy.pos.z);
    dry = Opponent(rule=rule, pos=Vec3(x=-200.0, z=60.0), walk_speed=rule.speed);
    dry.water_depth = 0;
    world +>:HasOpponent:+> dry;
    for i in range(30) {
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=0.01
        );
    }
    assert dry.pos.z < 60.0;
    biter = Opponent(rule=rule, pos=Vec3(x=270.0, z=40.0), attack_wait=0.0);
    biter.water_depth = 3;
    world +>:HasOpponent:+> biter;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=1.5);
    assert biter.attack_event == 3 and player.health < 100;
}

test "sight pain and death cues use registered speakers" {
    rule = enemy_rule("q1", "monster_demon1");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=400.0));
    enemy = Opponent(rule=rule, attack_wait=5.0, health=300);
    for path in [rule.sight_sound, rule.pain_sounds[0], rule.death_sound] {
        speaker = Speaker(path=path, origin=Vec3());
        world +>:HasSpeaker:+> speaker;
        enemy.speakers.append(speaker);
        enemy.speaker_paths.append(path);
    }
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.01
    );
    assert enemy.speakers[0].requests == 1;
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=state, dt=0.2
    );
    assert enemy.speakers[0].requests == 1;
    damage_opponent(enemy, 250);
    assert enemy.speakers[1].requests == 1 and enemy.pain_wait > 0.0;
    damage_opponent(enemy, 300);
    assert enemy.speakers[2].requests == 1 and enemy.health == 0;
}

test "mid leap save restores motion and reproduces the uninterrupted trajectory and hit" {
    rule = enemy_rule("q1", "monster_demon1");
    assert rule is not None;
    world = World();
    level = Level(name="leap-save");
    level.bsp.game = "q1";
    level.collision = floor_map();
    player = Player(pos=Vec3(x=180.0, z=22.0));
    enemy = Opponent(
        rule=rule, pos=Vec3(z=22.01), grounded=True, attack_wait=0.0, shot_random=5
    );
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q1");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.05
    );
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.3
    );
    assert enemy.leaping and not enemy.grounded;
    velocity = enemy.velocity.add(Vec3());
    saved = snapshot(world, level, player, state);
    for i in range(40) {
        world spawn CombatTick(
            player=player, collision=level.collision, state=state, dt=0.01
        );
    }
    expected_health = player.health;
    expected_pos = enemy.pos.add(Vec3());
    expected_velocity = enemy.velocity.add(Vec3());
    assert expected_health < 100;
    # Simulate a fresh/resting actor before loading the airborne state.
    enemy.velocity = Vec3();
    enemy.grounded = True;
    restore(world, level, player, state, saved);
    assert enemy.leaping and not enemy.grounded;
    assert enemy.velocity.sub(velocity).length() < 0.000001;
    for i in range(40) {
        world spawn CombatTick(
            player=player, collision=level.collision, state=state, dt=0.01
        );
    }
    assert player.health == expected_health;
    assert enemy.pos.sub(expected_pos).length() < 0.001;
    assert enemy.velocity.sub(expected_velocity).length() < 0.001;
}
