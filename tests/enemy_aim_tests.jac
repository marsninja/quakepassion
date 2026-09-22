import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, opponent_shot }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "soldier delayed aim allows a fast strafe to dodge pellets" {
    rule = enemy_rule("q1", "monster_army");
    assert rule is not None;
    world = World();
    collision = CollisionMap();
    enemy = Opponent(rule=rule);
    player = Player(pos=Vec3(x=120.0));
    opponent_shot(world, enemy, player, collision);
    assert player.health < 100;
    first_stream = enemy.shot_random;
    player.health = 100;
    player.velocity = Vec3(y=1000.0);
    enemy.shot_random = 1;
    opponent_shot(world, enemy, player, collision);
    assert player.health == 100 and enemy.shot_random == first_stream;
}

test "enemy pellet traces cannot damage through geometry" {
    rule = enemy_rule("q1", "monster_army");
    assert rule is not None;
    world = World();
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=50.0, y=-100.0, z=-100.0),
        Vec3(x=60.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    player = Player(pos=Vec3(x=120.0));
    opponent_shot(world, Opponent(rule=rule), player, collision);
    assert player.health == 100;
}
