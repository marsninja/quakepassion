"""Bots taking the passages that need more than walking: bobbing platforms on
q3dm19 and q3tourney6, and rocket jumps on q3dm17 (where every bot is handed
a rocket launcher, rockets and armor, so BotCanAndWantsToRocketJump holds).
Runs QP_SECONDS (default 90) per map with the movers ticking and counts, per
bot, the special passages it set out on and those it finished (entered the
passage's target area)."""
import os;
import from engine.core.menu { game_directory }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick, ProjectileTick }
import from engine.world.arena { MatchTick, match_of }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.bot_ai { BotTactics }
import from engine.world.wading { ImmerseBots }
import from engine.world.bot_routes { NavMesh, HasNavMesh }
import from engine.world.pickups { PickupTick }
import from engine.world.doors { DoorTick }
import from engine.world.rotators { RotatorTick }
import from engine.world.inventory { AdjustInventory }
import from engine.formats.aas { TRAVEL_FUNCBOB, TRAVEL_ELEVATOR, TRAVEL_ROCKETJUMP }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }

with entry {
    seconds = float(os.getenv("QP_SECONDS", "90"));
    dt = 1.0 / 120.0;
    finished_total = 0;
    for name in ["q3dm19", "q3tourney6", "q3dm17"] {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3", 3);
        populate_pickups(world, level, game_directory("q3"));
        populate_opponents(world, level, game_directory("q3"));
        prepare_arena_links(world, level.collision);
        mesh = [world->:HasNavMesh:->][?:NavMesh][0];
        contest = match_of(world);
        assert contest is not None;
        contest.warmup = 0.0;
        bots = [bot for bot in [world->:HasOpponent:->][?:Opponent] if bot.arena];
        player = Player(health=0, pos=Vec3(z=-100000.0));
        state = CombatState(game="q3");
        equip_player(player, state, "q3");
        contacts = ArenaContactIndex();
        started: list[dict[int, int]] = [{} for bot in bots];
        finished: list[dict[int, int]] = [{} for bot in bots];
        leg_kind: list[int] = [0 for bot in bots];
        leg_area: list[int] = [0 for bot in bots];
        for tick in range(int(seconds / dt)) {
            if name == "q3dm17" and tick % 120 == 0 {
                for bot in bots {
                    if bot.health > 0 {
                        bot.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1, capacity=1);
                        bot.inventory spawn AdjustInventory(kind="rockets", amount=20, capacity=200);
                        bot.health = max(bot.health, 100);
                        bot.armor = max(bot.armor, 50);
                    }
                }
            }
            world spawn PickupTick(player=player, start=player.pos, finish=player.pos, dt=dt);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt);
            world spawn DoorTick(bsp=level.bsp, collision=level.collision, player_origin=player.pos, dt=dt, touching=False);
            world spawn RotatorTick(bsp=level.bsp, collision=level.collision, dt=dt);
            world spawn ImmerseBots(level=level, dt=dt);
            world spawn CombatTick(player=player, collision=level.collision, state=state, dt=dt, arena_live=True);
            world spawn BotTactics(player=player, collision=level.collision, state=state, rules=state.rules, dt=dt, map_name=name, level=level);
            world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=dt);
            world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt, contacts=True);
            contest spawn MatchTick(dt=dt);
            state.messages = [];
            state.cues = [];
            for i in range(len(bots)) {
                bot = bots[i];
                route = bot.bot_state.route;
                passage = route.passages[0] if route.passages and len(route.points) == len(bot.route) and bot.route else None;
                kind = 0;
                target = 0;
                if passage is not None and passage.kind in [TRAVEL_FUNCBOB, TRAVEL_ELEVATOR, TRAVEL_ROCKETJUMP] {
                    kind = passage.kind;
                    target = passage.target;
                }
                if kind != 0 and (kind != leg_kind[i] or target != leg_area[i]) {
                    started[i][kind] = started[i].get(kind, 0) + 1;
                    leg_kind[i] = kind;
                    leg_area[i] = target;
                }
                if leg_kind[i] != 0 {
                    if mesh.locate(bot.pos.sub(Vec3(z=bot.eye_height))) == leg_area[i] {
                        finished[i][leg_kind[i]] = finished[i].get(leg_kind[i], 0) + 1;
                        leg_kind[i] = 0;
                        leg_area[i] = 0;
                    } elif kind == 0 {
                        leg_kind[i] = 0;
                        leg_area[i] = 0;
                    }
                }
            }
        }
        for i in range(len(bots)) {
            mind = bots[i].character;
            label = mind.name if mind is not None else "?";
            print("TYPES " + name + " " + label + " started " + str(started[i]) + " finished " + str(finished[i]));
            for (kind, count) in finished[i].items() {
                finished_total += count;
            }
        }
    }
    print("TRAVEL TYPES DONE finished " + str(finished_total));
    assert finished_total > 0;
}
