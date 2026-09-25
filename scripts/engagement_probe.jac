"""Measures how campaign monsters fight a standing player: how far they move,
how much of the fight they spend moving, and how often they attack."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level }
import from engine.world.world { World, Player }
import from engine.world.combat { CombatState, CombatTick, ProjectileTick, Opponent, HasOpponent }
import from games.opponents { populate_opponents }
import from engine.math.vec3 { Vec3 }

"""An open spot `reach` units from `origin` with a clear line back to it."""
def probe_spot(level: Level, origin: Vec3, reach: float) -> Vec3 | None {
    for offset in [Vec3(x=1.0), Vec3(x=-1.0), Vec3(y=1.0), Vec3(y=-1.0), Vec3(x=0.7, y=0.7), Vec3(x=-0.7, y=-0.7), Vec3(x=0.7, y=-0.7), Vec3(x=-0.7, y=0.7)] {
        spot = origin.add(offset.scale(reach));
        if level.collision.trace_point(spot, spot).start_solid {
            continue;
        }
        if level.collision.trace_point(origin, spot).fraction < 1.0 {
            continue;
        }
        # Stand on a floor below the spot.
        floor = level.collision.trace_point(spot, spot.sub(Vec3(z=200.0)));
        if floor.fraction == 1.0 {
            continue;
        }
        return spot;
    }
    return None;
}

with entry {
    cases: list[tuple[str, str]] = [("q1", "e1m1"), ("q1", "e1m2"), ("q1", "e2m1"), ("q2", "base1"), ("q2", "base2")];
    total_moving = 0.0;
    total_time = 0.0;
    total_attacks = 0;
    for scenario in cases {
        game = scenario[0];
        name = scenario[1];
        world = World();
        level = load_level(world, game_directory(game), name, game);
        populate_opponents(world, level, game_directory(game));
        opponents = [world->:HasOpponent:->][?:Opponent];
        fighters = [
            enemy for enemy in opponents
            if enemy.health > 0 and not enemy.dormant and enemy.profiles
            and not enemy.rule.inert and not enemy.rule.decoration and not enemy.rule.script
            and enemy.rule.movement == "walk"
        ];
        tried = 0;
        for enemy in fighters {
            if tried >= 5 {
                break;
            }
            spot = probe_spot(level, enemy.pos, 350.0);
            if spot is None {
                continue;
            }
            tried += 1;
            player = Player(health=100000, god_mode=True, pos=spot);
            state = CombatState(game=game);
            enemy.alert = 8.0;
            enemy.last_seen = spot;
            dt = 1.0 / 60.0;
            travelled = 0.0;
            moving = 0.0;
            attacks = 0;
            was_attacking = False;
            closest = 100000.0;
            for tick in range(60 * 10) {
                before = enemy.pos.add(Vec3());
                world spawn CombatTick(player=player, collision=level.collision, state=state, dt=dt);
                world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=dt);
                step = enemy.pos.sub(before);
                step.z = 0.0;
                travelled += step.length();
                if step.length() > 0.5 {
                    moving += dt;
                }
                attacking = enemy.attack_clock >= 0.0;
                if attacking and not was_attacking {
                    attacks += 1;
                }
                was_attacking = attacking;
                closest = min(closest, enemy.pos.sub(player.pos).length());
                if enemy.health <= 0 {
                    break;
                }
            }
            total_moving += moving;
            total_time += 10.0;
            total_attacks += attacks;
            print(
                "ENGAGE", game, name, enemy.kind,
                "moved", int(travelled), "moving_s", round(moving, 1),
                "attacks", attacks, "closest", int(closest),
                "end_dist", int(enemy.pos.sub(player.pos).length())
            );
            enemy.alert = 0.0;
            enemy.pos = Vec3(z=-100000.0);
            enemy.health = 0;
        }
    }
    print("ENGAGE TOTAL moving_fraction", round(total_moving / max(1.0, total_time), 2), "attacks_per_10s", round(float(total_attacks) / max(1.0, total_time / 10.0), 1));
}
