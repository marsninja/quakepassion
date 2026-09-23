"""Original maps: monsters gib into their own models and turn on each other."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level, spawn_player }
import from engine.world.world { World, Player }
import from engine.world.combat { CombatState, CombatTick, ProjectileTick, Opponent, HasOpponent, damage_opponent, provoked }
import from engine.world.gibs { Gib, HasGib, GibTick }
import from engine.world.patrols { Patrols, Holds, PatrolTick }
import from engine.world.trains { TrackPoint }
import from games.opponents { populate_opponents }
import from engine.render.models { ModelScene }
import from engine.render.quake { QuakeRenderer }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3 }

def look_at(renderer: Renderer, drawing: QuakeRenderer, scene: ModelScene, level: Level, world: World, eye: Vec3, target: Vec3, name: str) {
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
    renderer.screenshot(name);
}

"""An open spot `reach` units from `origin` with a clear line back to it."""
def open_spot(level: Level, origin: Vec3, reach: float) -> Vec3 | None {
    for offset in [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(y=-1.0), Vec3(x=0.7, y=0.7), Vec3(x=-0.7, y=-0.7)] {
        spot = origin.add(offset.scale(reach));
        if level.collision.trace_point(spot, spot).start_solid {
            continue;
        }
        if level.collision.trace_point(origin, spot).fraction == 1.0 {
            return spot;
        }
    }
    return None;
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    cases: list[tuple[str, str]] = [("q1", "e1m1"), ("q1", "e1m2"), ("q2", "base1"), ("q3", "q3dm1")];
    for scenario in cases {
        game = scenario[0];
        name = scenario[1];
        world = World();
        level = load_level(world, game_directory(game), name, game);
        populate_opponents(world, level, game_directory(game));
        scene = ModelScene();
        scene.upload(world);
        drawing = QuakeRenderer();
        drawing.upload(level);
        player = Player(health=100000, god_mode=True, pos=Vec3(z=-100000.0));
        state = CombatState(game=game);
        opponents = [world->:HasOpponent:->][?:Opponent];
        gibbable = [enemy for enemy in opponents if enemy.gib_rule is not None and not enemy.dormant];
        print("MONSTERS", game, name, "opponents", len(opponents), "gibbable", len(gibbable));
        assert gibbable;
        # Blow the first monster with a clear view apart.
        victim: Opponent | None = None;
        eye = Vec3();
        for enemy in gibbable {
            spot = open_spot(level, enemy.pos, 160.0);
            if spot is not None {
                victim = enemy;
                eye = spot;
                break;
            }
        }
        assert victim is not None;
        damage_opponent(victim, victim.health + 300);
        assert victim.gibbed and not victim.visual.visible;
        world spawn CombatTick(player=player, collision=level.collision, state=state, dt=1.0 / 120.0, active=True);
        flying = len([world->:HasGib:->][?:Gib]);
        assert flying > 0;
        for tick in range(30) {
            world spawn GibTick(collision=level.collision, dt=1.0 / 60.0);
        }
        focus = victim.pos.sub(Vec3(z=victim.eye_height));
        look_at(renderer, drawing, scene, level, world, eye.add(Vec3(z=24.0)), focus, "qp_monsters_" + name + "_gibs.png");
        for tick in range(240) {
            world spawn GibTick(collision=level.collision, dt=1.0 / 60.0);
        }
        settled = [gib for gib in [world->:HasGib:->][?:Gib] if gib.resting];
        print("GIBS", game, name, "thrown", flying, "settled", len(settled));
        # Idle patrols walk their authored path corners.
        if game != "q3" {
            patrollers = [enemy for enemy in opponents if [enemy->:Patrols:->] and enemy.health > 0 and not enemy.dormant];
            holders = [enemy for enemy in opponents if [enemy->:Holds:->]];
            print("PATROLS", game, name, "patrolling", len(patrollers), "combat points", len(holders));
            if patrollers {
                starts = [enemy.pos.add(Vec3()) for enemy in patrollers];
                goals = [[enemy->:Patrols:->][?:TrackPoint][0] for enemy in patrollers];
                for tick in range(120 * 12) {
                    world spawn PatrolTick(dt=1.0 / 120.0);
                    world spawn CombatTick(player=player, collision=level.collision, state=state, dt=1.0 / 120.0);
                }
                walked = 0;
                advanced = 0;
                for i in range(len(patrollers)) {
                    if patrollers[i].pos.sub(starts[i]).length() > 16.0 {
                        walked += 1;
                    }
                    now = [patrollers[i]->:Patrols:->][?:TrackPoint];
                    if not now or now[0] is not goals[i] {
                        advanced += 1;
                    }
                }
                print("PATROLS", game, name, "walked", walked, "advanced", advanced);
                assert walked > 0 and advanced > 0;
            }
        }
        # Infighting: a campaign monster hurt by a different kind hunts it down.
        if game != "q3" {
            fighter: Opponent | None = None;
            target: Opponent | None = None;
            arena_spot = Vec3();
            for first in opponents {
                if first.health <= 0 or first.dormant or first.rule.inert or first.rule.decoration or not first.profiles {
                    continue;
                }
                crowded = False;
                for other in opponents {
                    if other is not first and other.health > 0 and other.pos.sub(first.pos).length() < 250.0 {
                        crowded = True;
                    }
                }
                room = open_spot(level, first.pos, 200.0);
                if crowded or room is None {
                    continue;
                }
                arena_spot = room;
                for second in opponents {
                    if second is first or second.health <= 0 or second.dormant or second.rule.inert or second.rule.decoration {
                        continue;
                    }
                    if provoked(first, second) and first.rule.movement == "walk" {
                        fighter = first;
                        target = second;
                        break;
                    }
                }
                if fighter is not None {
                    break;
                }
            }
            assert fighter is not None and target is not None;
            target.pos = arena_spot;
            target.attack_wait = 1000.0;
            start = target.health;
            damage_opponent(fighter, 1, attacker=target);
            assert fighter.foe is target;
            for tick in range(120 * 8) {
                world spawn CombatTick(player=player, collision=level.collision, state=state, dt=1.0 / 120.0);
                world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=1.0 / 120.0);
                if target.health < start {
                    break;
                }
            }
            print("INFIGHT", game, name, fighter.kind, "vs", target.kind, "health", start, "->", target.health);
            assert target.health < start;
        }
        print("MONSTERS PASS", game, name);
        scene.close();
        drawing.close();
    }
    renderer.close();
}
