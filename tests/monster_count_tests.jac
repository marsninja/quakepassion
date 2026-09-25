"""The level's monster total and kill tally: Q1 counts Chthon and
Shub-Niggurath, Q2 leaves out its AI_GOOD_GUY misc_insane figures."""
import from engine.world.monster_count { monster_total }
import from engine.world.combat { Opponent, HasOpponent, CombatState, damage_opponent }
import from engine.world.world { World }
import from games.enemies { enemy_rule }

def roster_world(game: str, kinds: list[str]) -> World {
    world = World();
    for kind in kinds {
        rule = enemy_rule(game, kind);
        assert rule is not None;
        world +>:HasOpponent:+> Opponent(rule=rule, health=rule.health, max_health=rule.health, game=game);
    }
    return world;
}

test "Q1 counts its bosses among the level's monsters" {
    world = roster_world("q1", ["monster_army", "monster_boss", "monster_oldone"]);
    assert monster_total(world) == 3;
}

test "Q2 leaves insane marines out of the total and the kills" {
    world = roster_world("q2", ["monster_soldier", "misc_insane", "turret_driver"]);
    assert monster_total(world) == 2;
    state = CombatState(game="q2");
    for enemy in [world->:HasOpponent:->][?:Opponent] {
        damage_opponent(enemy, 1000, state=state);
    }
    assert state.kills == 2;
}
