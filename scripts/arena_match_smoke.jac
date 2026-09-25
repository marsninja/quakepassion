"""Original ladder arenas: rosters, models, spawns and a simulated bot match."""
import from engine.core.menu { game_directory }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick }
import from engine.world.arena { MatchTick, SpawnPoint, HasSpawn, match_of, standings }
import from engine.world.bot_tactics { BotTactics }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.models { ModelResource, PlayerRig, Wears, Holds, WeaponKit }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }

with entry {
    cases: list[tuple[str, int, int]] = [("q3dm1", 1, 10), ("q3dm5", 2, 15), ("q3dm6", 5, 20)];
    for scenario in cases {
        name = scenario[0];
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3");
        populate_pickups(world, level, game_directory("q3"));
        populate_opponents(world, level, game_directory("q3"));
        prepare_arena_links(world, level.collision);
        contest = match_of(world);
        assert contest is not None;
        assert contest.fraglimit == scenario[2];
        bots = [bot for bot in [world->:HasOpponent:->][?:Opponent] if bot.arena];
        assert len(bots) == scenario[1];
        assert len([world->:HasSpawn:->][?:SpawnPoint]) >= 4;
        names = [row.name for row in standings(contest)];
        # Every bot wears its three tagged parts and holds a weapon.
        for bot in bots {
            rig = bot.visual;
            assert isinstance(rig, PlayerRig) and len(rig.clips) == 27;
            assert len([rig->:Wears:->][?:ModelResource]) == 3 and [rig->:Holds:->][?:WeaponKit];
        }
        # A spectator player far away lets the bots fight among themselves.
        player = Player(health=0, pos=Vec3(z=-100000.0));
        state = CombatState(game="q3");
        equip_player(player, state, "q3");
        contest.warmup = 0.0;
        contacts = ArenaContactIndex();
        frags = 0;
        deaths = 0;
        # Twenty simulated seconds of bots-only play must run without faults.
        for tick in range(120 * 20) {
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=1.0 / 120.0);
            world spawn CombatTick(
                player=player,
                collision=level.collision,
                state=state,
                dt=1.0 / 120.0,
                arena_live=True
            );
            world spawn BotTactics(player=player, collision=level.collision, state=state, rules=state.rules, dt=1.0 / 120.0);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=1.0 / 120.0, contacts=True);
            contest spawn MatchTick(dt=1.0 / 120.0);
            if contest.finished {
                break;
            }
        }
        for row in standings(contest) {
            frags += max(0, row.frags);
            deaths += row.deaths;
        }
        print("ARENA", name, names, "frags", frags, "deaths", deaths, "finished", contest.finished);
    }
    print("ARENA MATCH PASS");
}
