"""Monsters on their own boxes in the original maps, with screenshots in
.jac/screenshots/hulls/: the Q2 supertank (power1), Jorg (boss2) and tanks
(jail2) and Q1's shambler (e1m5) start clear of the floor, settle with their
feet on it, and a boss walked toward an opening that a player-sized monster
passes stops at its own edge."""
import math;
import os;
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level }
import from engine.world.world { World, Player }
import from engine.world.combat { CombatState, CombatTick, Opponent, HasOpponent, monster_collision }
import from engine.physics.movement { MovePlayer }
import from games.opponents { populate_opponents }
import from engine.render.models { ModelScene }
import from engine.render.quake { QuakeRenderer }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3 }

def hull_look(renderer: Renderer, drawing: QuakeRenderer, scene: ModelScene, level: Level, world: World, eye: Vec3, target: Vec3, name: str) {
    direction = target.sub(eye);
    yaw = math.atan2(direction.y, direction.x);
    pitch = math.atan2(direction.z, math.sqrt(direction.x * direction.x + direction.y * direction.y));
    for frame in range(3) {
        renderer.begin_frame(eye, yaw, pitch);
        drawing.draw(level, level.visible(world, eye, False), eye);
        scene.draw(world, eye, 1.0);
        renderer.end_scene();
        renderer.end_frame();
    }
    renderer.screenshot(".jac/screenshots/hulls/" + name);
    print("HULL SHOT", name);
}

"""A point-clear spot about `reach` from `focus`, at `lift` above it, that
can see it."""
def hull_view(level: Level, focus: Vec3, reach: float, lift: float) -> Vec3 {
    best = focus.add(Vec3(z=lift));
    for step in range(16) {
        angle = float(step) * math.pi / 8.0;
        spot = focus.add(Vec3(x=math.cos(angle) * reach, y=math.sin(angle) * reach, z=lift));
        if level.collision.trace_point(spot, spot).start_solid {
            continue;
        }
        if level.collision.trace_point(spot, focus.add(Vec3(z=40.0))).fraction == 1.0 {
            return spot;
        }
    }
    return best;
}

with entry {
    os.makedirs(".jac/screenshots/hulls", exist_ok=True);
    renderer = Renderer();
    renderer.open_window();
    for scene_case in [("q2", "power1", "monster_supertank"), ("q2", "boss2", "monster_jorg"), ("q2", "jail2", "monster_tank"), ("q1", "e1m5", "monster_shambler")] {
        game = scene_case[0];
        name = scene_case[1];
        world = World();
        level = load_level(world, game_directory(game), name, game);
        populate_opponents(world, level, game_directory(game));
        scene = ModelScene();
        scene.upload(world);
        drawing = QuakeRenderer();
        drawing.upload(level);
        player = Player(health=100000, god_mode=True, pos=Vec3(z=-100000.0));
        state = CombatState(game=game);
        bosses = [enemy for enemy in [world->:HasOpponent:->][?:Opponent] if enemy.kind == scene_case[2] and not enemy.dormant];
        assert bosses and bosses[0].own_hull;
        boss = bosses[0];
        body = monster_collision(level.collision, boss);
        origin = boss.pos.sub(Vec3(z=boss.eye_height));
        assert not body.trace(origin, origin).start_solid;
        for i in range(240) {
            world spawn CombatTick(player=player, collision=level.collision, state=state, dt=1.0 / 120.0, active=True);
        }
        origin = boss.pos.sub(Vec3(z=boss.eye_height));
        feet = origin.add(Vec3(z=boss.rule.hull_bottom));
        floor = level.collision.trace_point(feet.add(Vec3(z=2.0)), feet.sub(Vec3(z=64.0)));
        gap = feet.z - floor.end.z;
        print("HULL STAND", name, boss.kind, "grounded", boss.grounded, "feet above floor", gap);
        assert boss.grounded and gap < 2.5 and gap > -0.5;
        focus = feet.add(Vec3(z=(boss.rule.hull_top - boss.rule.hull_bottom) * 0.5));
        eye = hull_view(level, focus, 96.0 + boss.rule.width * 3.0, 24.0);
        hull_look(renderer, drawing, scene, level, world, eye, focus, name + "_" + boss.kind + "_stands.png");
        # Find an opening a player-sized body walks through but this box does not.
        if game == "q2" {
            best_dir = Vec3();
            best_gain = 0.0;
            for step in range(32) {
                angle = float(step) * math.pi / 16.0;
                heading = Vec3(x=math.cos(angle), y=math.sin(angle));
                start = origin.add(Vec3(z=1.0));
                small = level.collision.trace(start.add(Vec3(z=24.0)), start.add(Vec3(z=24.0)).add(heading.scale(768.0)));
                large = body.trace(start, start.add(heading.scale(768.0)));
                gain = small.fraction - large.fraction;
                if not small.start_solid and gain > best_gain {
                    best_gain = gain;
                    best_dir = heading;
                }
            }
            print("HULL GAP", name, "player reaches", best_gain, "further along", best_dir.x, best_dir.y);
            if best_gain > 0.1 {
                boss.yaw = math.atan2(best_dir.y, best_dir.x);
                boss.walk_speed = 120.0;
                for i in range(600) {
                    boss spawn MovePlayer(collision=body, wish=best_dir, steady=True, dt=1.0 / 120.0);
                }
                stop = boss.pos.sub(Vec3(z=boss.eye_height));
                reach = stop.sub(origin).dot(best_dir);
                ahead = level.collision.trace(stop.add(Vec3(z=25.0)), stop.add(Vec3(z=25.0)).add(best_dir.scale(768.0)));
                print("HULL BLOCKED", name, "walked", reach, "player-size body could go", ahead.fraction * 768.0, "more");
                assert ahead.fraction * 768.0 > 32.0;
                focus = stop.add(Vec3(z=boss.rule.hull_top * 0.5));
                eye = focus.sub(best_dir.scale(160.0 + boss.rule.width * 2.0)).add(Vec3(z=48.0));
                if level.collision.trace_point(eye, eye).start_solid {
                    eye = hull_view(level, focus, 160.0 + boss.rule.width * 2.0, 48.0);
                }
                hull_look(renderer, drawing, scene, level, world, eye, focus.add(best_dir.scale(boss.rule.width)), name + "_" + boss.kind + "_blocked.png");
            }
        }
    }
    renderer.close();
    print("MONSTER HULL SMOKE PASS");
}
