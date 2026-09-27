"""Original arenas: bots load their botlib characters, collect weapons across the
map, choose and fire them, and frag each other."""
import from engine.core.menu { game_directory }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick, ProjectileTick }
import from engine.world.arena { MatchTick, match_of, standings }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.bot_tactics { BotTactics }
import from engine.world.pickups { PickupTick }
import from engine.world.doors { DoorTick }
import from engine.world.inventory { quantity }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }

with entry {
    arsenal = ["shotgun", "grenadelauncher", "rocketlauncher", "lightning", "railgun", "plasmagun", "bfg"];
    total_frags = 0;
    for name in ["q3dm7", "q3dm6", "q3tourney2"] {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3");
        populate_pickups(world, level, game_directory("q3"));
        populate_opponents(world, level, game_directory("q3"));
        prepare_arena_links(world, level.collision);
        contest = match_of(world);
        assert contest is not None;
        contest.warmup = 0.0;
        bots = [bot for bot in [world->:HasOpponent:->][?:Opponent] if bot.arena];
        for bot in bots {
            mind = bot.character;
            assert mind is not None and mind.weights;
            print("BOT", name, mind.name, "skill", mind.skill, "accuracy", round(mind.aim_accuracy, 2),
                "reaction", round(mind.reaction, 2), "weights", len(mind.weights));
            assert quantity(bot.inventory, "weapon_machinegun") == 1 and quantity(bot.inventory, "bullets") == 100;
        }
        player = Player(health=0, pos=Vec3(z=-100000.0));
        state = CombatState(game="q3");
        equip_player(player, state, "q3");
        contacts = ArenaContactIndex();
        for tick in range(120 * 60) {
            dt = 1.0 / 120.0;
            world spawn PickupTick(player=player, start=player.pos, finish=player.pos, dt=dt);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt);
            # Bots open doors by walking into their trigger fields (Touch_DoorTrigger).
            world spawn DoorTick(bsp=level.bsp, collision=level.collision, player_origin=player.pos, dt=dt, touching=False);
            world spawn CombatTick(player=player, collision=level.collision, state=state, dt=dt, arena_live=True);
            world spawn BotTactics(player=player, collision=level.collision, state=state, rules=state.rules, dt=dt);
            world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=dt);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt, contacts=True);
            contest spawn MatchTick(dt=dt);
            if contest.finished {
                break;
            }
        }
        frags = 0;
        for row in standings(contest) {
            frags += max(0, row.frags);
        }
        armed: list[str] = [];
        for bot in bots {
            for weapon in arsenal {
                if quantity(bot.inventory, "weapon_" + weapon) > 0 and weapon not in armed {
                    armed.append(weapon);
                }
            }
        }
        rows = [row.name + ":" + str(row.frags) for row in standings(contest)];
        print("COMBAT", name, "bots", len(bots), "frags", frags, "scores", rows, "weapons held", armed);
        total_frags += frags;
    }
    assert total_frags > 0;
    print("BOT COMBAT PASS");
}
