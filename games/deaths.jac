"""How each game's player dies (engine/world/demise.jac plays these rules):
Q1 player.qc PlayerDie, GibPlayer and client.qc PlayerDeathThink, Q2
p_client.c player_die, ThrowClientHead and ClientBeginServerFrame with
pmove.c PM_CheckDuck, Q3 g_combat.c player_die and GibEntity with bg_pmove.c
PM_CheckDuck and g_active.c ClientThink_real."""
import from .gibs { gib_rule, link_gibs }
import from engine.world.demise { DeathRule, BodyForm, Mortality, HasMortality }
import from engine.world.world { World, Player }
import from engine.world.models { ModelResource, HasModelResource }
import from engine.assets.catalog { AssetCatalog }

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
            looks=True,
            gibs=gib_rule("q1", "player"),
            head=BodyForm(eye_height=-16.0),
            head_thrown=True,
            head_bounce=0.5
        );
    }
    if game == "q2" {
        return DeathRule(
            lying=BodyForm(top_drop=28.0, eye_height=-2.0),
            delay=1.0,
            latches=True,
            any_key=True,
            gibs=gib_rule("q2", "player"),
            shootable=True,
            head=BodyForm(top_drop=40.0, eye_height=-16.0, lift=56.0),
            head_thrown=True,
            head_keeps_speed=True,
            head_drags=False
        );
    }
    if game == "q3" {
        return DeathRule(
            lying=BodyForm(top_drop=40.0, eye_height=-16.0),
            delay=1.7,
            forced=20.0,
            gibs=gib_rule("q3", "player"),
            shootable=True,
            whole_in_void=True,
            head=BodyForm(top_drop=40.0, eye_height=-16.0)
        );
    }
    return DeathRule(tossed=True, kick=300.0, delay=1.0, release_first=True, looks=True);
}

"""Give the level's player its game's death. With a `world` and the game's
`directory` the body is linked to the gib models it bursts into, sharing
those the level's monsters already loaded; a game whose data lacks them
leaves the body whole."""
def prepare_death(player: Player, game: str, world: World | None = None, directory: str = "") {
    fallen = Mortality(rule=death_rule(game));
    player +>:HasMortality:+> fallen;
    gibs = fallen.rule.gibs;
    if gibs is None or world is None {
        return;
    }
    resources: dict[str, ModelResource] = {};
    for resource in [world->:HasModelResource:->][?:ModelResource] {
        if resource.name.startswith("gib:") {
            resources[resource.name] = resource;
        }
    }
    catalog = AssetCatalog(game=game, directory=directory);
    try {
        if not link_gibs(world, player, gibs, catalog.source(game), game, resources) {
            fallen.rule.gibs = None;
        }
    } except Exception {
        fallen.rule.gibs = None;
    } finally {
        catalog.close();
    }
}
