"""The level's monster total, as the intermission and help computer count it."""
import from .world { World }
import from .combat { Opponent, HasOpponent }

"""Q1 monsters.qc walkmonster_start and the like add each monster to
total_monsters, and so do monster_boss (Chthon) and monster_oldone
(Shub-Niggurath) themselves; Q2 monster_start counts every monster but the
AI_GOOD_GUY ones (misc_insane). Arena bots,
decorations and inert bodies are not monsters."""
def monster_total(world: World) -> int {
    return len(
        [
            enemy
            for enemy in [world->:HasOpponent:->][?:Opponent]
            if not enemy.arena
                and not enemy.rule.decoration
                and not enemy.rule.inert
                and not enemy.rule.good_guy
        ]
    );
}
