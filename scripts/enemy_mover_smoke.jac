"""Native acceptance for enemy door contact and platform carrying."""
import from tests.door_support { DoorFixture }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.doors { Door, HasDoor }
import from engine.math.vec3 { Vec3 }

with entry {
    for game in ["q1", "q2", "q3"] {
        door_fixture = DoorFixture();
        door_fixture.setup(game);
        door_fixture.world +>:HasOpponent:+> Opponent(pos=Vec3(x=40.0, z=46.0));
        door_fixture.tick(Vec3(x=500.0));
        door = [door_fixture.world->:HasDoor:->][?:Door][0];
        assert door.state == "opening" and door.position > 0.0;
        fixture = DoorFixture();
        fixture.setup(game, {"classname": "func_plat", "height": "64", "speed": "64"});
        platform = [fixture.world->:HasDoor:->][?:Door][0];
        enemy = Opponent(pos=Vec3(z=56.03125 + fixture.collision.eye_height));
        fixture.world +>:HasOpponent:+> enemy;
        before = enemy.pos.z;
        for i in range(4) {
            fixture.tick(Vec3(x=500.0), 0.25);
        }
        assert platform.position == 1.0;
        assert abs(enemy.pos.z - before - 64.0) < 0.00001;
        platform.state = "closing";
        for i in range(4) {
            fixture.tick(Vec3(x=500.0), 0.25);
        }
        assert platform.position == 0.0;
        assert abs(enemy.pos.z - before) < 0.00001;
        print(game, "ENEMY MOVER PASS");
    }
}
