"""A bot rocket-jumps on q3dm17. One bot, armed for rocket jumps and alone, is
set down where the only way to its goal is a rocket jump (a pair the AAS joins
only with TFL_ROCKETJUMP) and given that goal. It must look down, jump, fire,
fly and land in the passage's target area, spending a rocket."""
import os;
import from engine.core.menu { game_directory }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick, ProjectileTick }
import from engine.world.arena { MatchTick, match_of }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.bot_ai { BotTactics }
import from engine.world.wading { ImmerseBots }
import from engine.world.bot_routes { NavMesh, HasNavMesh, plan_route }
import from engine.world.bot_goals { BotItems, LevelItem, HasLevelItem, BotGoal, bot_items }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.formats.aas { TFL_DEFAULT, TFL_ROCKETJUMP, TRAVEL_ROCKETJUMP }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }

with entry {
    name = os.getenv("QP_MAP", "q3dm17");
    dt = 1.0 / 120.0;
    world = World();
    level = load_level(world, game_directory("q3"), name, "q3", 3);
    populate_pickups(world, level, game_directory("q3"));
    populate_opponents(world, level, game_directory("q3"));
    prepare_arena_links(world, level.collision);
    mesh = [world->:HasNavMesh:->][?:NavMesh][0];
    items = bot_items(world);
    assert items is not None;
    contest = match_of(world);
    assert contest is not None;
    contest.warmup = 0.0;
    bots = [bot for bot in [world->:HasOpponent:->][?:Opponent] if bot.arena];
    bot = bots[0];
    for other in bots[1:] {
        other.dormant = True;
    }
    # A spawn point or item from which only a rocket jump reaches an item.
    goals = [item for item in [items->:HasLevelItem:->][?:LevelItem] if item.goal_area > 0];
    starts: list[Vec3] = [];
    for entity in level.bsp.entities {
        if entity.fields.get("classname", "") == "info_player_deathmatch" {
            parts = entity.fields.get("origin", "0 0 0").split();
            spot = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            landing = level.collision.trace(spot.add(Vec3(z=16.0)), spot.sub(Vec3(z=512.0)));
            starts.append(landing.end);
        }
    }
    for item in goals {
        if mesh.locate(item.goal_origin) == item.goal_area {
            starts.append(item.goal_origin);
        }
    }
    chosen_start = Vec3();
    chosen: LevelItem | None = None;
    for start in starts {
        for item in goals {
            mesh.times_to(item.goal_area);
            mesh.times_to(item.goal_area, TFL_DEFAULT | TFL_ROCKETJUMP);
            walking = plan_route(mesh, start, item.goal_origin, 256, TFL_DEFAULT, item.goal_area);
            jumping = plan_route(mesh, start, item.goal_origin, 256, TFL_DEFAULT | TFL_ROCKETJUMP, item.goal_area);
            first = jumping.passages[0] if jumping.passages else None;
            if chosen is None and not walking.found and jumping.found and first is not None and first.kind == TRAVEL_ROCKETJUMP {
                chosen = item;
                chosen_start = start;
            }
        }
    }
    target = chosen;
    assert target is not None;
    print("RJ from " + str([int(chosen_start.x), int(chosen_start.y), int(chosen_start.z)]) + " to " + target.info.classname
        + " area " + str(target.goal_area));
    player = Player(health=0, pos=Vec3(z=-100000.0));
    state = CombatState(game="q3");
    equip_player(player, state, "q3");
    contacts = ArenaContactIndex();
    bot.pos = chosen_start.add(Vec3(z=bot.eye_height));
    bot.velocity = Vec3();
    bot.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1, capacity=1);
    bot.inventory spawn AdjustInventory(kind="rockets", amount=20, capacity=200);
    bot.health = 100;
    bot.armor = 100;
    jumped = False;
    reached = False;
    for tick in range(int(15.0 / dt)) {
        memory = bot.bot_state;
        # The goal, kept on top of its stack (as a long-term goal would be).
        top = memory.goals.top();
        if top is None or top.item is not target {
            memory.goals.push(BotGoal(origin=target.goal_origin, area=target.goal_area, mins=target.info.mins, maxs=target.info.maxs, number=target.number, item=target));
            memory.ltg_time = 100000.0;
        }
        world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt);
        world spawn ImmerseBots(level=level, dt=dt);
        world spawn CombatTick(player=player, collision=level.collision, state=state, dt=dt, arena_live=True);
        world spawn BotTactics(player=player, collision=level.collision, state=state, rules=state.rules, dt=dt, map_name=name, level=level);
        world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=dt);
        world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt, contacts=True);
        travel = memory.travel;
        if travel.jump and travel.weapon == "rocketlauncher" {
            jumped = True;
        }
        if tick % 12 == 0 {
            print("t=" + str(round(float(tick) * dt, 2)) + " node " + memory.ainode + " pos " + str([int(bot.pos.x), int(bot.pos.y), int(bot.pos.z)])
                + " vel " + str([int(bot.velocity.x), int(bot.velocity.y), int(bot.velocity.z)]) + " view " + str([round(memory.yaw, 1), round(memory.pitch, 1)])
                + " weapon " + str(bot.weapon_slot) + " rockets " + str(quantity(bot.inventory, "rockets")) + " health " + str(bot.health)
                + " area " + str(mesh.locate(bot.pos.sub(Vec3(z=bot.eye_height)))) + " jumped " + str(jumped));
        }
        if mesh.locate(bot.pos.sub(Vec3(z=bot.eye_height))) == target.goal_area {
            reached = True;
            break;
        }
    }
    print("ROCKET JUMP " + ("reached" if reached else "failed") + " jumped " + str(jumped) + " rockets " + str(quantity(bot.inventory, "rockets")));
    assert jumped and reached and quantity(bot.inventory, "rockets") < 20;
}
