"""Soak and profile of an arena with a live player standing at spawn:
QP_SECONDS (default 30) of play on each map in QP_MAPS (default q3dm12, the
heaviest ladder arena, and q3dm7), timing the navigation, doors, combat
(movement and routes) and bot (AI and aim) walkers per 120 Hz tick. Built
natively it is the headless repro for the arena crashes the bots' weapon
pickups (string views stored in lists) and the collector (a collection inside
a destructor) caused; it should finish every map with exit 0."""
import os;
import time;
import from engine.core.menu { game_directory }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick, ProjectileTick }
import from engine.world.arena { MatchTick, match_of }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.bot_ai { BotTactics }
import from engine.world.doors { DoorTick }
import from engine.world.pickups { PickupTick }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }

with entry {
    maps = os.getenv("QP_MAPS", "q3dm12,q3dm7").split(",");
    seconds = float(os.getenv("QP_SECONDS", "30"));
    dt = 1.0 / 120.0;
    for name in maps {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3", 2);
        populate_pickups(world, level, game_directory("q3"));
        populate_opponents(world, level, game_directory("q3"));
        prepare_arena_links(world, level.collision);
        contest = match_of(world);
        assert contest is not None;
        contest.warmup = 0.0;
        spot = spawn_player(level).pos;
        player = Player(health=100, pos=spot.add(Vec3(z=26.0)));
        state = CombatState(game="q3");
        equip_player(player, state, "q3");
        contacts = ArenaContactIndex();
        spent_nav = 0.0;
        spent_combat = 0.0;
        spent_doors = 0.0;
        spent_bots = 0.0;
        worst = 0.0;
        ticks = int(seconds / dt);
        for tick in range(ticks) {
            began = time.perf_counter();
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt);
            navigated = time.perf_counter();
            world spawn DoorTick(bsp=level.bsp, collision=level.collision, player_origin=player.pos, dt=dt, touching=False);
            opened = time.perf_counter();
            world spawn PickupTick(player=player, start=player.pos, finish=player.pos, dt=dt);
            world spawn CombatTick(player=player, collision=level.collision, state=state, dt=dt, arena_live=True);
            fought = time.perf_counter();
            world spawn BotTactics(player=player, collision=level.collision, state=state, rules=state.rules, dt=dt);
            thought = time.perf_counter();
            world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=dt);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt, contacts=True);
            contest spawn MatchTick(dt=dt);
            for line in state.messages {
                print("MSG " + str(tick) + " " + line);
            }
            if tick % 12 == 0 {
                print("T " + str(tick) + " player " + str(player.health) + " bots " + str([bot.health for bot in [world->:HasOpponent:->][?:Opponent]]));
            }
            if player.health <= 0 and tick % 240 == 0 {
                player.health = 100;
                player.pos = spot.add(Vec3(z=26.0));
            }
            state.messages = [];
            state.cues = [];
            spent_nav += navigated - began;
            spent_doors += opened - navigated;
            spent_combat += fought - opened;
            spent_bots += thought - fought;
            worst = max(worst, thought - began);
        }
        bots = len([bot for bot in [world->:HasOpponent:->][?:Opponent] if bot.arena]);
        print("PROFILE " + name + " bots " + str(bots) + " ms/tick navigation "
            + str(round(1000.0 * spent_nav / float(ticks), 3)) + " doors "
            + str(round(1000.0 * spent_doors / float(ticks), 3)) + " combat "
            + str(round(1000.0 * spent_combat / float(ticks), 3)) + " bots "
            + str(round(1000.0 * spent_bots / float(ticks), 3)) + " worst tick "
            + str(round(1000.0 * worst, 2)));
    }
}
