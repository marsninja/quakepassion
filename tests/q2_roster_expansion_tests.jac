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

test "gunner chaingun burst refires and grenades need distance" {
    rule = enemy_rule("q2", "monster_gunner");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=60.0));
    enemy = Opponent(rule=rule, attack_wait=0.0, shot_random=9);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    assert choose_attack(enemy, 60.0) == 0;
    world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=0.65);
    assert player.health == 100 and enemy.attack_profile == 0;
    # The player stands still: friction takes each shot's kick away before
    # the next (GunnerFire leads the target by its velocity from the muzzle,
    # 35 units ahead of the gunner).
    for step in range(8) {
        world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=0.1);
        player.velocity = Vec3();
    }
    assert player.health <= 76 and player.health >= 70 , str(player.health);
    far = Opponent(rule=rule, attack_wait=0.0, shot_random=30000);
    chosen = choose_attack(far, 400.0);
    assert chosen == 0 or chosen == 1;
    grenadier = Opponent(rule=rule, attack_wait=0.0, attack_profile=1, attack_clock=0.0);
    grenadier.attack_melee = False;
    other = World();
    other +>:HasOpponent:+> grenadier;
    other spawn CombatTick(
        player=Player(pos=Vec3(x=400.0)), collision=CollisionMap(), state=state, dt=0.45
    );
    shells = [other->:HasProjectile:->][?:Projectile];
    assert len(shells) == 1 and shells[0].gravity and shells[0].splash == 50;
}

test "gunner pain sequences depend on damage dealt" {
    rule = enemy_rule("q2", "monster_gunner");
    assert rule is not None;
    for pair in [(5, 1), (20, 2), (60, 3)] {
        enemy = Opponent(rule=rule, health=175, max_health=175);
        damage_opponent(enemy, pair[0]);
        assert enemy.pain_variant == pair[1] , str(enemy.pain_variant);
        assert abs(enemy.pain_wait - rule.pain_variant_durations[pair[1] - 1]) < 0.001;
    }
}

test "flyer hovers and loops its blade slash while in reach" {
    rule = enemy_rule("q2", "monster_flyer");
    assert rule is not None and rule.movement == "fly" and rule.vanish_on_death;
    world = World();
    collision = floor_map();
    player = Player(pos=Vec3(x=60.0, z=30.0));
    enemy = Opponent(rule=rule, pos=Vec3(z=40.0), walk_speed=rule.speed, attack_wait=0.0, shot_random=1, health=50);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.85);
    assert enemy.attack_melee and player.health == 95 , str(player.health);
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.5);
    assert player.health == 90;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.5);
    assert enemy.attack_clock >= 0.0 and enemy.attack_clock < 1.3 , str(enemy.attack_clock);
    damage_opponent(enemy, 50);
    assert enemy.health == 0 and not enemy.visual.visible;
}

test "mutant claws refire in reach and its leap launches from distance" {
    rule = enemy_rule("q2", "monster_mutant");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=60.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=0.55);
    first = player.health;
    assert first <= 86 and first >= 72 , str(first);
    world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=0.7);
    assert player.health < first;
    jumper = Opponent(rule=rule, pos=Vec3(z=22.01), grounded=True, attack_wait=0.0);
    other = World();
    other +>:HasOpponent:+> jumper;
    other spawn CombatTick(
        player=Player(pos=Vec3(x=200.0, z=22.0)), collision=floor_map(), state=state, dt=0.25
    );
    assert jumper.leaping and jumper.velocity.x > 500.0;
}

test "parasite drain beam applies per event damage within its range" {
    rule = enemy_rule("q2", "monster_parasite");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=150.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=0.25);
    assert player.health == 95;
    world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=1.0);
    assert player.health == 75 , str(player.health);
    trails = [world->:HasTrail:->][?:ShotTrail];
    assert trails and trails[0].kind == "drain";
    far = Opponent(rule=rule, attack_wait=0.0);
    assert choose_attack(far, 300.0) == -1;
}

test "brain tentacles pull the player and claws push" {
    rule = enemy_rule("q2", "monster_brain");
    assert rule is not None;
    for seed in [1, 30000] {
        world = World();
        player = Player(pos=Vec3(x=60.0, z=22.0));
        enemy = Opponent(
            rule=rule, pos=Vec3(z=22.01), grounded=True, attack_wait=0.0, shot_random=seed
        );
        world +>:HasOpponent:+> enemy;
        state = CombatState(game="q2");
        world spawn CombatTick(player=player, collision=floor_map(), state=state, dt=1.15);
        assert player.health < 100;
        if enemy.attack_profile == 0 {
            assert player.velocity.x > 0.0;
        } else {
            assert player.velocity.x < 0.0;
        }
    }
}

test "tank chooses by range and sweeps its machine gun" {
    rule = enemy_rule("q2", "monster_tank");
    assert rule is not None;
    commander = enemy_rule("q2", "monster_tank_commander");
    assert commander is not None and commander.health == 1000 and commander.skin == 2;
    near = Opponent(rule=rule, shot_random=1);
    assert choose_attack(near, 100.0) in [0, 1];
    world = World();
    player = Player(pos=Vec3(x=200.0));
    enemy = Opponent(rule=rule, attack_wait=0.0, attack_profile=1, attack_clock=0.0, health=750);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=1.05);
    assert enemy.attack_event == 6;
    assert player.health <= 100 and player.health >= 0;
    assert player.health < 100 , str(player.health);
    damage_opponent(enemy, 10);
    assert enemy.pain_wait == 0.0;
    damage_opponent(enemy, 70);
    assert enemy.pain_variant == 3;
}

test "supertank rockets are preferred at range and its chaingun repeats" {
    rule = enemy_rule("q2", "monster_supertank");
    assert rule is not None and rule.width == 64.0;
    assert choose_attack(Opponent(rule=rule), 100.0) == 0;
    world = World();
    player = Player(pos=Vec3(x=500.0));
    enemy = Opponent(rule=rule, attack_wait=0.0, attack_profile=1, attack_clock=0.0, health=1500);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=1.35);
    assert len([world->:HasProjectile:->]) == 3;
}

test "hornet fires four rockets at once and jorg spawns makron" {
    rule = enemy_rule("q2", "monster_boss2");
    assert rule is not None and rule.movement == "fly";
    world = World();
    player = Player(pos=Vec3(x=500.0));
    enemy = Opponent(rule=rule, attack_wait=0.0, attack_profile=1, attack_clock=0.0, health=2000);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=1.25);
    assert len([world->:HasProjectile:->]) == 4;
    jorg_rule = enemy_rule("q2", "monster_jorg");
    makron_rule = enemy_rule("q2", "monster_makron");
    assert jorg_rule is not None and makron_rule is not None;
    assert jorg_rule.successor == "monster_makron";
    level = Level(name="boss");
    level.bsp.game = "q2";
    arena = World();
    jorg = Opponent(rule=jorg_rule, health=3000, death_animation=[1, 2, 3]);
    makron = Opponent(rule=makron_rule, dormant=True, health=3000);
    jorg.successor = makron;
    arena +>:HasOpponent:+> jorg;
    arena +>:HasOpponent:+> makron;
    damage_opponent(jorg, 3000);
    assert jorg.health == 0 and makron.dormant and makron.spawn_wait < 0.0;
    arena spawn CombatTick(player=player, collision=level.collision, state=state, dt=0.3);
    assert makron.spawn_wait > 0.0 and makron.velocity.z == 200.0;
    saved = snapshot(arena, level, player, state);
    restore(arena, level, player, state, saved);
    assert makron.dormant and abs(makron.spawn_wait - 0.5) < 0.001;
    for i in range(10) {
        arena spawn CombatTick(player=player, collision=level.collision, state=state, dt=0.1);
    }
    assert not makron.dormant and makron.visual.visible;
}

test "makron hyperblaster sweeps across yaw offsets and rail shot locks aim" {
    rule = enemy_rule("q2", "monster_makron");
    assert rule is not None;
    world = World();
    player = Player(pos=Vec3(x=400.0));
    enemy = Opponent(rule=rule, attack_wait=0.0, attack_profile=1, attack_clock=0.0, health=3000);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=0.45);
    bolts = [world->:HasProjectile:->][?:Projectile];
    assert len(bolts) == 1 and bolts[0].velocity.y > 900.0 , str(bolts[0].velocity.y);
    rail = Opponent(rule=rule, attack_wait=0.0, attack_profile=2, attack_clock=0.0, health=3000);
    rail.attack_target = Vec3(x=400.0);
    lane = World();
    lane +>:HasOpponent:+> rail;
    lane spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=0.85);
    assert player.health == 50 and [lane->:HasTrail:->];
}

test "hostile bfg orb lasers the player and bursts at impact" {
    rule = enemy_rule("q2", "monster_jorg");
    assert rule is not None;
    world = World();
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=300.0, y=-300.0, z=-300.0),
        Vec3(x=301.0, y=300.0, z=300.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    player = Player(pos=Vec3(x=200.0, y=100.0));
    enemy = Opponent(rule=rule, attack_wait=0.0, attack_profile=1, attack_clock=0.0, health=3000);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.65);
    orbs = [world->:HasProjectile:->][?:Projectile];
    assert len(orbs) == 1 and orbs[0].beam_damage == 10 and orbs[0].hostile;
    for i in range(12) {
        world spawn ProjectileTick(player=player, collision=collision, state=state, dt=0.1);
    }
    assert player.health < 100 , str(player.health);
}

test "flipper stays a swimmer and static bodies ignore damage" {
    rule = enemy_rule("q2", "monster_flipper");
    assert rule is not None and rule.movement == "swim";
    body = enemy_rule("q2", "monster_commander_body");
    assert body is not None and body.decoration;
    statue = Opponent(rule=body, health=1);
    damage_opponent(statue, 50);
    assert statue.health == 1;
    # Crucified marines hang still and harmless but can be killed.
    crucified = enemy_rule("q2", "misc_insane", 8);
    assert crucified is not None and crucified.passive and crucified.movement == "none";
    assert not crucified.decoration;
    marine = enemy_rule("q2", "misc_insane");
    assert marine is not None and not marine.decoration;
    assert choose_attack(Opponent(rule=marine), 50.0) == -1;
}
