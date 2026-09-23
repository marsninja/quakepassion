import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat {
    CombatState,
    CombatTick,
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    ProjectileTick,
    damage_opponent,
    opponent_shot
}
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

def monster(game: str, kind: str, pos: Vec3) -> Opponent {
    rule = enemy_rule(game, kind, 0);
    assert rule is not None;
    return Opponent(
        rule=rule, kind=kind, game=game, pos=pos, health=rule.health, max_health=rule.health
    );
}

test "monsters turn on other kinds that hurt them as Q1 and Q2 decide" {
    ogre = monster("q1", "monster_ogre", Vec3());
    knight = monster("q1", "monster_knight", Vec3(x=100.0));
    other_knight = monster("q1", "monster_knight", Vec3(x=200.0));
    damage_opponent(ogre, 1, attacker=knight);
    assert ogre.foe is knight and ogre.alert > 0.0;
    # Q1 T_Damage: the same class shrugs it off, except soldiers.
    damage_opponent(other_knight, 1, attacker=knight);
    assert other_knight.foe is None and other_knight.alert == 0.0;
    grunt = monster("q1", "monster_army", Vec3());
    damage_opponent(grunt, 1, attacker=monster("q1", "monster_army", Vec3(x=64.0)));
    assert grunt.foe is not None;
    # Q2 M_ReactToDamage: tanks spray too much, fliers ignore walkers.
    gunner = monster("q2", "monster_gunner", Vec3());
    damage_opponent(gunner, 1, attacker=monster("q2", "monster_tank", Vec3(x=100.0)));
    assert gunner.foe is None;
    damage_opponent(gunner, 1, attacker=monster("q2", "monster_flyer", Vec3(x=100.0)));
    assert gunner.foe is None;
    infantry = monster("q2", "monster_infantry", Vec3(x=100.0));
    damage_opponent(gunner, 1, attacker=infantry);
    assert gunner.foe is infantry;
    # A Q2 monster hit by its own kind joins that monster's fight instead.
    rival = monster("q2", "monster_berserk", Vec3(x=400.0));
    shooter = monster("q2", "monster_soldier", Vec3(x=100.0));
    shooter.foe = rival;
    buddy = monster("q2", "monster_soldier", Vec3());
    damage_opponent(buddy, 1, attacker=shooter);
    assert buddy.foe is rival;
}

test "monster fire strikes whoever stands in the line of fire" {
    world = World();
    collision = CollisionMap();
    state = CombatState();
    grunt = monster("q1", "monster_army", Vec3());
    ogre = monster("q1", "monster_ogre", Vec3(x=80.0));
    player = Player(pos=Vec3(x=200.0));
    world +>:HasOpponent:+> grunt;
    world +>:HasOpponent:+> ogre;
    opponent_shot(world, grunt, player, collision, tally=state);
    assert player.health == 100 and ogre.health < ogre.max_health;
    assert ogre.foe is grunt;
    # The shooter never hits itself.
    assert grunt.health == grunt.max_health;
}

test "monster missiles hit other monsters but never their owner" {
    world = World();
    collision = CollisionMap();
    state = CombatState();
    ogre = monster("q1", "monster_ogre", Vec3());
    knight = monster("q1", "monster_knight", Vec3(x=100.0));
    world +>:HasOpponent:+> ogre;
    world +>:HasOpponent:+> knight;
    player = Player(pos=Vec3(x=2000.0));
    world +>:HasProjectile:+> Projectile(
        pos=Vec3(x=10.0), velocity=Vec3(x=600.0), damage=40, hostile=True, owner=ogre
    );
    for i in range(30) {
        world spawn ProjectileTick(player=player, collision=collision, state=state, dt=0.01);
    }
    assert knight.health < knight.max_health and knight.foe is ogre;
    assert ogre.health == ogre.max_health and player.health == 100;
}

test "infighting monsters fight, count kills and return to the player" {
    world = World();
    collision = CollisionMap();
    state = CombatState();
    player = Player(pos=Vec3(x=-600.0));
    knight = monster("q1", "monster_knight", Vec3());
    dog = monster("q1", "monster_dog", Vec3(x=50.0));
    world +>:HasOpponent:+> knight;
    world +>:HasOpponent:+> dog;
    # The knight was already hunting the player when the dog bit it.
    knight.alert = 8.0;
    damage_opponent(knight, 1, attacker=dog);
    assert knight.foe is dog and knight.resume_hunt;
    for i in range(400) {
        knight.decision_wait = 0.0;
        dog.attack_wait = 10.0;
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
        if dog.health <= 0 {
            break;
        }
    }
    assert dog.health <= 0 and state.kills == 1 and player.health == 100;
    world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    assert knight.foe is None and knight.alert > 0.0;
    assert knight.last_seen.sub(player.pos).length() < 1.0;
}
