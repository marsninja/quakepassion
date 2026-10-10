"""Bots and jump reachabilities (be_ai_move.c BotTravel_Jump). On each map a
lone bot is set down, standing still, at the run start of a sample of the
AAS's jump passages (those a route from there to the passage's far end takes
first) and sent across. A jump counts when the bot stands in the passage's
target area within six seconds, alive; however it got there. For each jump
missed the line gives the areas, the jump's length and rise, how far from
the passage's start and how fast (horizontally/upward) the bot first left
the ground, and where it first came down. `QP_MAPS` names the maps,
`QP_JUMPS` how many jumps to try on each (12 by default), and `QP_TRACE`
one passage ("from>to" areas) to print the bot's position, velocity and
travel for, twenty times a second."""
import os;
import from engine.core.menu { game_directory }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick, ProjectileTick }
import from engine.world.arena { match_of }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.bot_ai { BotTactics }
import from engine.world.bot_character { BotState }
import from engine.world.wading { ImmerseBots }
import from engine.world.bot_routes { NavMesh, HasNavMesh, Passage, Exits, plan_route, jump_run_start }
import from engine.world.bot_goals { BotGoal }
import from engine.formats.aas { TRAVEL_JUMP }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }

with entry {
    dt = 1.0 / 120.0;
    wanted = int(os.getenv("QP_JUMPS", "12"));
    total = 0;
    made = 0;
    for name in os.getenv("QP_MAPS", "q3dm6,q3dm7,q3dm12,q3dm13,q3dm17").split(",") {
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
        bot = bots[0];
        for other in bots[1:] {
            other.dormant = True;
        }
        # Every jump passage a bot can be stood at the run start of, whose
        # own far end it is routed to by that jump.
        jumps: list[tuple[Passage, Vec3]] = [];
        count = 0;
        for area in mesh.areas {
            for passage in [area->:Exits:->][?:Passage] {
                if passage.kind != TRAVEL_JUMP {
                    continue;
                }
                count += 1;
                run = jump_run_start(mesh, passage.source, passage);
                begin = run if run is not None else passage.start;
                landing = level.collision.trace(begin.add(Vec3(z=40.0)), begin.sub(Vec3(z=64.0)));
                if landing.start_solid or mesh.locate(landing.end) != passage.source {
                    continue;
                }
                mesh.times_to(passage.target);
                route = plan_route(mesh, landing.end, passage.finish, goal_area=passage.target);
                if route.found and route.passages and route.passages[0] is passage {
                    jumps.append((passage, landing.end));
                }
            }
        }
        step = max(1, len(jumps) // max(1, wanted));
        sample = [jumps[i] for i in range(0, len(jumps), step)][0:wanted];
        player = Player(health=0, pos=Vec3(z=-100000.0));
        state = CombatState(game="q3");
        equip_player(player, state, "q3");
        contacts = ArenaContactIndex();
        landed = 0;
        missed: list[str] = [];
        for trial in sample {
            passage = trial[0];
            bot.pos = trial[1].add(Vec3(z=bot.eye_height + 1.0));
            bot.velocity = Vec3();
            bot.health = 100;
            bot.grounded = False;
            bot.rest_serial = -1;
            bot.bot_state = BotState();
            bot.route = [];
            bot.route_areas = [];
            bot.route_wait = 0.0;
            # No greeting on the way.
            mind = bot.character;
            if mind is not None {
                mind.chat_state.entered_chat = True;
            }
            ok = False;
            # Where the bot first left the ground and where it first came
            # down again, for the jumps it misses.
            left = "";
            down = "";
            for tick in range(int(6.0 / dt)) {
                memory = bot.bot_state;
                top = memory.goals.top();
                if top is None or top.area != passage.target {
                    memory.goals.empty();
                    memory.goals.push(BotGoal(origin=passage.finish, area=passage.target));
                    memory.ltg_time = 100000.0;
                }
                world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt);
                world spawn ImmerseBots(level=level, dt=dt);
                world spawn CombatTick(player=player, collision=level.collision, state=state, dt=dt, arena_live=True);
                world spawn BotTactics(player=player, collision=level.collision, state=state, rules=state.rules, dt=dt, map_name=name, level=level);
                world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=dt);
                world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt, contacts=True);
                if bot.health <= 0 {
                    break;
                }
                feet = bot.pos.sub(Vec3(z=bot.eye_height));
                if os.getenv("QP_TRACE", "") == str(passage.source) + ">" + str(passage.target) and tick % 6 == 0 and tick < 360 {
                    moving = bot.bot_state.travel;
                    print("TRACE", tick, [int(feet.x), int(feet.y), int(feet.z)], "ground" if bot.grounded else "air",
                        [int(bot.velocity.x), int(bot.velocity.y), int(bot.velocity.z)], "move",
                        [round(moving.direction.x, 2), round(moving.direction.y, 2)], int(moving.speed), moving.jump,
                        "jumped", bot.bot_state.route.jumped, "legs", len(bot.bot_state.route.points), "area", mesh.locate(feet),
                        "start", [int(passage.start.x), int(passage.start.y), int(passage.start.z)],
                        "end", [int(passage.finish.x), int(passage.finish.y), int(passage.finish.z)]);
                }
                if not left and not bot.grounded and tick > 12 {
                    back = Vec3(x=feet.x - passage.start.x, y=feet.y - passage.start.y);
                    left = " left " + str(int(back.length())) + " from the start at "
                        + str(int(Vec3(x=bot.velocity.x, y=bot.velocity.y).length())) + "/" + str(int(bot.velocity.z));
                } elif left and not down and bot.grounded {
                    short = Vec3(x=passage.finish.x - feet.x, y=passage.finish.y - feet.y);
                    down = " down " + str(int(short.length())) + " from the end, " + str(int(feet.z - passage.finish.z))
                        + " above it, in area " + str(mesh.locate(feet));
                }
                if bot.grounded and mesh.locate(bot.pos.sub(Vec3(z=bot.eye_height))) == passage.target {
                    ok = True;
                    break;
                }
            }
            if ok {
                landed += 1;
            } else {
                gap = passage.finish.sub(passage.start);
                missed.append(
                    str(passage.source) + ">" + str(passage.target) + " " + str(int(Vec3(x=gap.x, y=gap.y).length())) + "/"
                    + str(int(gap.z)) + left + down + (" dead" if bot.health <= 0 else "")
                );
            }
        }
        total += len(sample);
        made += landed;
        print("JUMPS " + name + ": " + str(count) + " jump passages, " + str(len(jumps)) + " testable, " + str(landed) + "/" + str(len(sample))
            + " made; missed (areas, length/rise, takeoff and landing) " + str(missed));
    }
    print("BOT JUMPS " + str(made) + "/" + str(total));
}
