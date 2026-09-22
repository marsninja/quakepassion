"""Compare indexed collision with exhaustive hull queries on original maps."""
import from engine.core.menu { game_directory }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

with entry {
    for game in ["q1", "q2", "q3"] {
        name = "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1");
        level = load_level(World(), game_directory(game), name, game);
        indexed = level.collision;
        exhaustive = CollisionMap(
            hulls=indexed.hulls, point_hulls=indexed.point_hulls,
            offsets=indexed.offsets, models=indexed.models,
            eye_height=indexed.eye_height, top_drop=indexed.top_drop
        );
        centers = [spawn_player(level).pos];
        for i in range(1, len(indexed.bounds), max(1, len(indexed.bounds) // 16)) {
            centers.append(indexed.bounds[i].center());
        }
        checked = 0;
        for center in centers {
            for delta in [Vec3(x=128.0), Vec3(y=128.0), Vec3(z=128.0)] {
                for point in [False, True] {
                    start = center.add(delta);
                    finish = center.sub(delta);
                    a = indexed.trace(start, finish, point=point);
                    b = exhaustive.trace(start, finish, point=point);
                    assert a.start_solid == b.start_solid;
                    assert abs(a.fraction - b.fraction) < 0.000001;
                    checked += 1;
                }
            }
        }
        print("COLLISION INDEX PASS", game, checked);
    }
}
