"""Native actor-body isolation while the player crouches in Q2 and Q3."""
import from engine.world.combat { Opponent, HasOpponent, CombatTick, CombatState, Aim }
import from engine.world.world { World, Player }
import from engine.physics.collision { CollisionMap }
import from engine.physics.movement { SetStance }
import from engine.math.vec3 { Vec3 }

with entry {
    for game in ["q2", "q3"] {
        height = 22.0 if game == "q2" else 26.0;
        collision = CollisionMap(eye_height=height);
        collision.add_box(
            Vec3(x=-500.0, y=-500.0, z=-40.0),
            Vec3(x=500.0, y=500.0),
            Vec3(),
            Vec3(),
            Vec3()
        );
        player = Player(pos=Vec3(x=300.0, z=height + 0.03125), grounded=True);
        enemy = Opponent(
            pos=Vec3(z=height + 0.03125),
            eye_height=height,
            grounded=True,
            attack_wait=1000.0
        );
        world = World();
        world +>:HasOpponent:+> enemy;
        state = CombatState();
        player spawn SetStance(collision=collision, game=game, crouch=True, dt=0.01);
        for i in range(120) {
            world spawn CombatTick(
                player=player, collision=collision, state=state, dt=1.0 / 120.0
            );
        }
        assert abs(enemy.pos.z - height - 0.03125) < 0.001;
        assert collision.top_drop > 0.0;
        query = world spawn Aim(
            start=Vec3(x=enemy.pos.x - 100.0, z=-12.0),
            finish=Vec3(x=enemy.pos.x + 100.0, z=-12.0),
            height=collision.eye_height
        );
        assert query.target == enemy;
        print(game, "ENEMY STANCE PASS");
    }
}
