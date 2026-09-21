"""Native point queries against representative installed maps from all three games."""
import from engine.core.menu { game_directory }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.math.vec3 { Vec3 }

with entry {
    for game in ["q1", "q2", "q3"] {
        name = "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1");
        level = load_level(World(), game_directory(game), name, game);
        player = spawn_player(level);
        hits = 0;
        for direction in [
            Vec3(x=1.0),
            Vec3(x=-1.0),
            Vec3(y=1.0),
            Vec3(y=-1.0),
            Vec3(z=1.0),
            Vec3(z=-1.0)
        ] {
            finish = player.pos.add(direction.scale(8192.0));
            hit = level.collision.trace_point(player.pos, finish);
            assert not hit.start_solid;
            if hit.fraction == 1.0 {
                continue;
            }
            assert hit.fraction > 0.0 and hit.model >= 0;
            assert abs(hit.normal.length() - 1.0) < 0.001;
            assert hit.normal.dot(direction) < 0.0;
            before = hit.end.sub(direction.scale(0.25));
            assert level.collision.trace_point(player.pos, before).fraction == 1.0;
            beyond = hit.end.add(direction.scale(0.25));
            repeat = level.collision.trace_point(player.pos, beyond);
            assert repeat.fraction < 1.0;
            assert repeat.end.sub(hit.end).length() < 0.01;
            hits += 1;
        }
        assert hits >= 4;
        print("POINT TRACE PASS", game, name, hits, "surfaces");
    }
}
