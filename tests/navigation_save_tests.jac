import from engine.core.savegame { snapshot, restore }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat { Opponent, HasOpponent, CombatState }
import from engine.world.navigation { RouteSearch }
import from engine.math.vec3 { Vec3 }

test "restore preserves arena armor and cancels obsolete navigation jobs" {
    world = World();
    level = Level();
    player = Player();
    state = CombatState();
    enemy = Opponent(arena=True, armor=40, armor_capacity=100, armor_ratio=0.66);
    world +>:HasOpponent:+> enemy;
    saved = snapshot(world, level, player, state);
    enemy.armor = 0;
    pending = RouteSearch(start=Vec3(), finish=Vec3(x=200.0), collision=level.collision);
    enemy.route_search = pending;
    state.navigation.jobs.append(pending);
    enemy.arena_goal = Vec3(x=300.0);
    restore(world, level, player, state, saved);
    assert enemy.armor == 40 and enemy.armor_capacity == 100;
    assert abs(enemy.armor_ratio - 0.66) < 0.00001;
    assert pending.cancelled and enemy.route_search is None;
    assert enemy.arena_goal is None;
    state.navigation.advance();
    assert not state.navigation.jobs;
}
