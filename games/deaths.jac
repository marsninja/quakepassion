"""How each game's player dies (engine/world/demise.jac plays these rules):
Q1 player.qc PlayerDie and client.qc PlayerDeathThink, Q2 p_client.c
player_die and ClientBeginServerFrame with pmove.c PM_CheckDuck, Q3
g_combat.c player_die with bg_pmove.c PM_CheckDuck and g_active.c
ClientThink_real."""
import from engine.world.demise { DeathRule, BodyForm, Mortality, HasMortality }
import from engine.world.world { Player }

def death_rule(game: str) -> DeathRule {
    if game == "q1" {
        # PlayerDie picks player_diea1 to player_diee1 from 1 + floor(random()
        # * 6), the last twice; PlayerDead ends them on their 11th, 9th, 15th,
        # 9th and 9th frame at 10 Hz, and the axe's player_die_ax1 on its 9th.
        return DeathRule(
            lying=BodyForm(eye_height=-8.0),
            tossed=True,
            kick=300.0,
            sequences=[1.0, 0.8, 1.4, 0.8, 0.8, 0.8],
            weapon_sequences={"axe": 0.8},
            release_first=True,
            looks=True
        );
    }
    if game == "q2" {
        return DeathRule(
            lying=BodyForm(top_drop=28.0, eye_height=-2.0),
            delay=1.0,
            latches=True,
            any_key=True
        );
    }
    if game == "q3" {
        return DeathRule(
            lying=BodyForm(top_drop=40.0, eye_height=-16.0), delay=1.7, forced=20.0
        );
    }
    return DeathRule(tossed=True, kick=300.0, delay=1.0, release_first=True, looks=True);
}

"""Give the level's player its game's death."""
def prepare_death(player: Player, game: str) {
    player +>:HasMortality:+> Mortality(rule=death_rule(game));
}
