"""Native synthetic train traversal, activation and persistence regression."""
import from tests.train_tests { train_fixture }
import from engine.world.trains { Train, HasTrain, TrainTick }
import from engine.world.world { Player }
import from engine.math.vec3 { Vec3 }
import from engine.world.level { Level }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }
with entry {
    for game in ["q1", "q2", "q3"] {
        f = train_fixture(game);
        train = [f.world->:HasTrain:->][?:Train][0];
        player = Player(pos=Vec3(z=120.03125 + f.collision.eye_height));
        for i in range(120) {
            f.world spawn TrainTick(
                bsp=f.bsp, collision=f.collision, dt=1.0 / 120.0, player=player
            );
        }
        assert train.motion.z > 55.0 and train.motion.z <= 64.0;
        assert abs(player.pos.z - 120.03125 - f.collision.eye_height - train.motion.z)
            < 0.0001;
        before = train.motion.z;
        level = Level(bsp=f.bsp, collision=f.collision, name="test");
        data = snapshot(f.world, level, player, CombatState());
        f.world spawn TrainTick(
            bsp=f.bsp, collision=f.collision, dt=0.5, player=player
        );
        restore(f.world, level, player, CombatState(), data);
        assert train.motion.z == before and f.collision.offsets[0].z == before;
        print("TRAIN PASS", game);
    }
}
