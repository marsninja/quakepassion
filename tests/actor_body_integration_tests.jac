import from engine.world.combat { Opponent, HasOpponent, CombatState, fire_weapon }
import from engine.world.world { World, Player }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from tests.train_support { train_fixture }
import from engine.world.trains { Train, HasTrain, TrainTick }

test "a hit remembers the shooter's stance along with their position" {
    world = World();
    player = Player(pos=Vec3(z=-2.0), crouched=True);
    enemy = Opponent(pos=Vec3(x=100.0, z=22.0));
    world +>:HasOpponent:+> enemy;
    collision = CollisionMap(eye_height=-2.0, top_drop=28.0);
    assert fire_weapon(world, player, collision, CombatState());
    assert enemy.health < 100;
    assert enemy.last_seen_height == -2.0;
}

test "trains carry standing enemies independently of the player's crouch" {
    fixture = train_fixture();
    fixture.collision.eye_height = -2.0;
    fixture.collision.top_drop = 28.0;
    enemy = Opponent(pos=Vec3(z=142.03125));
    fixture.world +>:HasOpponent:+> enemy;
    for i in range(120) {
        fixture.world spawn TrainTick(
            bsp=fixture.bsp, collision=fixture.collision, dt=1.0 / 120.0
        );
    }
    train = [fixture.world->:HasTrain:->][?:Train][0];
    assert train.motion.z > 55.0;
    assert abs(enemy.pos.z - 142.03125 - train.motion.z) < 0.001;
}
