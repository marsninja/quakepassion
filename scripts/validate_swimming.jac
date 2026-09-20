"""Asset-backed liquid detection and collision-aware swimming."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.physics.movement { MovePlayer }
import from engine.math.vec3 { Vec3 }
import from scripts.swim_support { swim_points }

with entry {
    game = os.getenv("QP_GAME", "q1");
    folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
    directory = os.getenv("HOME", "") + "/quake-assets/" + folder;
    maps = ["start", "e1m1", "e1m2", "e1m3", "e2m1"];
    if game == "q2" {
        maps = ["base1", "base2", "base3", "jail1", "waste1"];
    }
    if game == "q3" {
        maps = ["q3dm1", "q3dm2", "q3dm7", "q3dm11", "q3dm12", "q3dm15"];
    }
    total = 0;
    for name in maps {
        level = load_level(World(), directory, name, game);
        samples = swim_points(level);
        if not samples {
            print("SWIM SKIP", game, name, "no clear submerged sample");
            continue;
        }
        player = Player(pos=samples[0]);
        before = player.pos;
        depth = level.immersion(player.pos).depth;
        for i in range(30) {
            state = level.immersion(player.pos);
            player spawn MovePlayer(
                collision=level.collision,
                water_depth=state.depth,
                swim_wish=Vec3(z=1.0)
            );
        }
        assert player.pos.z > before.z;
        origin = player.pos.sub(Vec3(z=level.collision.eye_height));
        assert not level.collision.trace(origin, origin).start_solid;
        print("SWIM PASS", game, name, "depth", depth, "rise", player.pos.z - before.z);
        total += 1;
    }
    assert total > 0;
    print("SWIMMING PASS", game, total);
}
