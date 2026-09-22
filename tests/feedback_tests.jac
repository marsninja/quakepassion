import from engine.world.world { World, Player }
import from engine.world.combat {
    CombatState,
    CombatTick,
    Opponent,
    HasOpponent,
    fire_weapon,
    damage_opponent
}
import from engine.world.particles {
    HasParticle,
    ImpactParticle,
    ParticleTick,
    impact_spray
}
import from engine.world.weapons { WeaponRule }
import from engine.world.inventory { AdjustInventory }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "shotgun wall feedback preserves pellet damage events and expires" {
    world = World();
    player = Player();
    player.inventory spawn AdjustInventory(kind="weapon_test", amount=1);
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=100.0, y=-100.0, z=-100.0),
        Vec3(x=110.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    state = CombatState(
        rules=[
            WeaponRule(
                slot=1,
                key="test",
                name="Test",
                pellets=6,
                spread=0.04,
                vertical_spread=0.04,
                damage=4
            )
        ]
    );
    assert fire_weapon(world, player, collision, state);
    assert len(state.impacts) == 6;
    particles = [world->:HasParticle:->][?:ImpactParticle];
    assert len(particles) == 48;
    for particle in particles {
        assert particle.pos.x < 100.0 and particle.velocity.x <= 0.0;
        assert not particle.blood;
    }
    world spawn ParticleTick(dt=1.0);
    assert len([world->:HasParticle:->]) == 0;
}

test "cosmetic saturation does not suppress damage or consume spread random state" {
    world = World();
    for i in range(100) {
        impact_spray(world, Vec3(), Vec3(x=-1.0));
    }
    assert len([world->:HasParticle:->]) == 512;
    victim = Opponent(pos=Vec3(x=100.0), health=60);
    world +>:HasOpponent:+> victim;
    state = CombatState();
    assert fire_weapon(world, Player(), CollisionMap(), state);
    assert victim.health == 45 and state.random_state == 1;
    assert len([world->:HasParticle:->]) == 512;
}

test "pain interrupts movement with cooldown and death holds the final pose" {
    world = World();
    victim = Opponent(
        pos=Vec3(x=100.0),
        pain_animation=[1, 2],
        death_animation=[3, 4, 5],
        attack_wait=5.0
    );
    world +>:HasOpponent:+> victim;
    assert damage_opponent(victim, 10) == 10;
    assert victim.pain_wait > 0.0;
    victim.pain_wait = 0.1;
    damage_opponent(victim, 10);
    assert victim.pain_wait == 0.1;
    damage_opponent(victim, 100);
    assert victim.visual.visible;
    world spawn CombatTick(
        player=Player(), collision=CollisionMap(), state=CombatState(), dt=1.0
    );
    assert victim.visual.first == 5 and victim.visual.second == 5;
}

test "turning follows the shortest arc with a bounded angular speed" {
    world = World();
    enemy = Opponent(pos=Vec3(x=100.0), yaw=0.0, attack_wait=5.0);
    world +>:HasOpponent:+> enemy;
    world spawn CombatTick(
        player=Player(), collision=CollisionMap(), state=CombatState(), dt=0.01
    );
    assert abs(enemy.yaw) <= 0.060001 and abs(enemy.yaw) > 0.0;
}
