import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick }
import from engine.world.particles { HasTrail, ShotTrail, ParticleTick }
import from engine.world.level { Level }
import from engine.world.speakers { Speaker, HasSpeaker }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }

test "berserker spike and club have different windups and damage" {
    for seed in [1, 30000] {
        rule = enemy_rule("q2", "monster_berserk");
        assert rule is not None;
        world = World();
        level = Level(name="berserk");
        player = Player(pos=Vec3(x=60.0));
        enemy = Opponent(rule=rule, shot_random=seed, attack_wait=0.0);
        world +>:HasOpponent:+> enemy;
        state = CombatState(game="q2");
        world spawn CombatTick(
            player=player, collision=level.collision, state=state, dt=0.2
        );
        assert player.health == 100;
        if seed == 1 {
            assert not enemy.alternate_melee;
            world spawn CombatTick(
                player=player, collision=level.collision, state=state, dt=0.1
            );
            assert player.health >= 80 and player.health <= 85;
        } else {
            assert enemy.alternate_melee;
            world spawn CombatTick(
                player=player, collision=level.collision, state=state, dt=0.5
            );
            assert player.health == 100;
            world spawn CombatTick(
                player=player, collision=level.collision, state=state, dt=0.1
            );
            assert player.health >= 90 and player.health <= 95;
        }
        assert abs(player.velocity.x - 400.0) < 0.001;
        assert enemy.attack_event == 1;
    }
}

test "gladiator locks aim during charge and keeps it across saves" {
    rule = enemy_rule("q2", "monster_gladiator");
    assert rule is not None;
    world = World();
    level = Level(name="rail");
    level.bsp.game = "q2";
    player = Player(pos=Vec3(x=300.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.2
    );
    saved = snapshot(world, level, player, state);
    player.pos.y = 100.0;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert player.health == 100 and len([world->:HasTrail:->]) == 1;
    enemy.attack_target = Vec3(y=900.0);
    restore(world, level, player, state, saved);
    assert enemy.attack_target.x == 300.0 and enemy.attack_target.y == 0.0;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert player.health == 50;
    world spawn ParticleTick(dt=0.3);
    assert not [world->:HasTrail:->];
}

test "gladiator rail respects world collision and safe zone" {
    rule = enemy_rule("q2", "monster_gladiator");
    assert rule is not None;
    world = World();
    level = Level(name="rail");
    player = Player(pos=Vec3(x=100.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert enemy.attack_clock < 0.0;
    player.pos.x = 300.0;
    enemy.decision_wait = 0.0;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.2
    );
    level.collision.add_box(
        Vec3(x=150.0, y=-100.0, z=-100.0),
        Vec3(x=151.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert player.health == 100;
    trails = [world->:HasTrail:->][?:ShotTrail];
    assert len(trails) == 1 and trails[0].finish.x <= 150.1;
}

test "gladiator cleaver strikes twice and rechecks escape range" {
    rule = enemy_rule("q2", "monster_gladiator");
    assert rule is not None;
    world = World();
    level = Level(name="cleaver");
    player = Player(pos=Vec3(x=60.0));
    enemy = Opponent(rule=rule, attack_wait=0.0);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.5
    );
    assert enemy.attack_melee and player.health == 100;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert player.health >= 76 and player.health <= 80;
    health = player.health;
    player.pos.x = 300.0;
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.7
    );
    assert enemy.attack_event == 2 and player.health == health;
    assert not [world->:HasTrail:->];
}

test "gladiator closes the rail safe zone to reach melee" {
    rule = enemy_rule("q2", "monster_gladiator");
    assert rule is not None;
    world = World();
    level = Level(name="approach");
    level.collision.add_box(
        Vec3(x=-200.0, y=-200.0, z=-10.0),
        Vec3(x=400.0, y=200.0, z=0.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    player = Player(pos=Vec3(x=100.0, z=22.0));
    enemy = Opponent(
        rule=rule,
        pos=Vec3(z=22.0),
        grounded=True,
        walk_speed=rule.speed,
        attack_wait=0.0
    );
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    for i in range(60) {
        world spawn CombatTick(
            player=player, collision=level.collision, state=state, dt=0.01
        );
    }
    assert enemy.pos.x > 20.0 and enemy.attack_melee;
    assert not [world->:HasTrail:->];
}


test "attack sound cues fire once at their authored time and resume after save" {
    rule = enemy_rule("q2", "monster_gladiator");
    assert rule is not None;
    world = World();
    level = Level(name="cue");
    level.bsp.game = "q2";
    player = Player(pos=Vec3(x=60.0));
    speaker = Speaker(path=rule.melee_sound, origin=Vec3());
    world +>:HasSpeaker:+> speaker;
    enemy = Opponent(rule=rule, attack_wait=0.0, melee_speaker=speaker);
    world +>:HasOpponent:+> enemy;
    state = CombatState(game="q2");
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.4
    );
    assert speaker.requests == 1;
    speaker.requests = 0;
    saved = snapshot(world, level, player, state);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.1
    );
    assert speaker.requests == 0;
    restore(world, level, player, state, saved);
    world spawn CombatTick(
        player=player, collision=level.collision, state=state, dt=0.6
    );
    assert speaker.requests == 1;
}
