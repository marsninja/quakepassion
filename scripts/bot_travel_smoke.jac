"""Original arenas: bots with the maps' AAS cover the whole map instead of
stalling. Set QP_NO_AAS=1 to compare against bounded local routing."""
import os;
import from engine.core.menu { game_directory }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick }
import from engine.world.arena { MatchTick, match_of, standings }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.bot_routes { NavMesh, HasNavMesh }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }

with entry {
    compare = os.getenv("QP_NO_AAS", "") == "1";
    for name in ["q3dm1", "q3dm7", "q3tourney2"] {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3");
        populate_pickups(world, level, game_directory("q3"));
        populate_opponents(world, level, game_directory("q3"));
        prepare_arena_links(world, level.collision);
        meshes = [world->:HasNavMesh:->][?:NavMesh];
        assert meshes;
        mesh = meshes[0];
        if compare {
            world del --> mesh;
        }
        contest = match_of(world);
        assert contest is not None;
        contest.warmup = 0.0;
        bots = [bot for bot in [world->:HasOpponent:->][?:Opponent] if bot.arena];
        player = Player(health=0, pos=Vec3(z=-100000.0));
        state = CombatState();
        equip_player(player, state, "q3");
        contacts = ArenaContactIndex();
        visited: list[set[int]] = [set() for bot in bots];
        travelled = [0.0 for bot in bots];
        last = [bot.pos.add(Vec3()) for bot in bots];
        for tick in range(120 * 40) {
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=1.0 / 120.0);
            world spawn CombatTick(player=player, collision=level.collision, state=state, dt=1.0 / 120.0, arena_live=True);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=1.0 / 120.0, contacts=True);
            contest spawn MatchTick(dt=1.0 / 120.0);
            if tick % 30 == 0 {
                for i in range(len(bots)) {
                    area = mesh.locate(bots[i].pos.sub(Vec3(z=bots[i].eye_height)));
                    if area > 0 {
                        visited[i].add(area);
                    }
                    step = bots[i].pos.sub(last[i]);
                    # Respawns and teleports are not travel.
                    if step.length() < 400.0 {
                        travelled[i] += step.length();
                    }
                    last[i] = bots[i].pos.add(Vec3());
                }
            }
        }
        frags = 0;
        for row in standings(contest) {
            frags += max(0, row.frags);
        }
        areas = [len(seen) for seen in visited];
        print("TRAVEL", "local" if compare else "aas", name, "bots", len(bots), "areas", areas,
            "distance", [int(d) for d in travelled], "frags", frags);
        if not compare {
            for count in areas {
                assert count >= 25;
            }
        }
    }
    print("BOT TRAVEL PASS");
}
