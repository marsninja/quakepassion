"""Native asset-backed movement checks; select Q1/Q2/Q3 with QP_GAME."""
import os;
import math;
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.physics.movement { MovePlayer }
import from engine.math.vec3 { Vec3 }

with entry {
    game = os.getenv("QP_GAME", "q1");
    folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
    directory = os.getenv(
        "QP_ASSETS", os.getenv("HOME", "") + "/quake-assets/" + folder
    );
    maps = ["e1m1", "start", "e1m2", "e2m1", "e3m1", "e4m1"];
    if game == "q2" {
        maps = ["base1", "base2", "base3"];
    }
    if game == "q3" {
        maps = ["q3dm1", "q3dm7", "q3tourney2"];
    }
    for name in maps {
        level = load_level(World(), directory, name, game);
        player = spawn_player(level);
        origin = player.pos.sub(Vec3(z=level.collision.eye_height));
        assert not level.collision.trace(origin, origin).start_solid;
        for i in range(240) {
            player spawn MovePlayer(collision=level.collision);
        }
        print(
            name,
            "settled",
            player.pos.x,
            player.pos.y,
            player.pos.z,
            "vz",
            player.velocity.z,
            "ground",
            player.grounded
        );
        assert player.grounded;
        grounded_height = player.pos.z;
        player spawn MovePlayer(collision=level.collision, jump=True);
        assert player.pos.z > grounded_height and player.velocity.z > 0.0;
        for i in range(240) {
            player spawn MovePlayer(collision=level.collision);
        }
        assert player.grounded;
        for i in range(480) {
            angle = float(i // 120) * math.pi / 2.0;
            player spawn MovePlayer(
                collision=level.collision,
                wish=Vec3(x=math.cos(angle), y=math.sin(angle))
            );
            origin = player.pos.sub(Vec3(z=level.collision.eye_height));
            assert not level.collision.trace(origin, origin).start_solid;
            assert math.isfinite(player.pos.z);
        }
        print(name, "collision, landing, jump, and four-direction movement passed");
    }
}
