"""Bots and the doors something else opens (ai_dmq3.c BotAIPredictObstacles,
BotGetActivateGoal, AINode_Seek_ActivateEntity). For every door of a map
that does not open by itself, one bot alone is set down at a spawn point or
item from where its route to another runs into the shut door, and given
that goal. The script reports what the bot first went to activate (a button
to press, a trigger to stand in, something to shoot), when the door opened
and when the bot, with nothing left to activate, got to its goal; a try
fails when it never does. `QP_MAPS` names the maps (q3dm7 and
q3dm11, the ladder arenas with such doors, by default), `QP_SECONDS` how
long each try may take, and `QP_VERBOSE=1` prints the bot twice a second."""
import os;
import from engine.core.menu { game_directory }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, CombatState, CombatTick, ProjectileTick }
import from engine.world.arena { match_of }
import from engine.world.arena_navigation { ArenaNavigationTick, ArenaContactIndex, prepare_arena_links }
import from engine.world.bot_ai { BotTactics }
import from engine.world.bot_character { BotState }
import from engine.world.bot_obstacles { FindActivator, brush_model }
import from engine.world.wading { ImmerseBots }
import from engine.world.doors { Door, HasDoor, DoorMember, DoorTick }
import from engine.world.signals { Signal, Targets, SignalTick }
import from engine.world.triggers { TriggerTick }
import from engine.world.trains { ShootMover }
import from engine.world.bot_routes { NavMesh, HasNavMesh, predict_mover, area_travel_time }
import from engine.world.bot_goals { LevelItem, HasLevelItem, BotGoal, bot_items }
import from engine.formats.aas { TFL_DEFAULT }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }

"""Whether the door with BSP `model` is shut."""
def door_shut(world: World, model: int) -> bool {
    for leader in [world->:HasDoor:->][?:Door] {
        parts = [leader];
        parts.extend([leader->:DoorMember:->][?:Door]);
        if model in [part.model for part in parts] {
            return leader.position == 0.0 and leader.state == "closed";
        }
    }
    return True;
}

with entry {
    dt = 1.0 / 120.0;
    seconds = float(os.getenv("QP_SECONDS", "40"));
    verbose = os.getenv("QP_VERBOSE", "0") == "1";
    failures: list[str] = [];
    for name in os.getenv("QP_MAPS", "q3dm7,q3dm11").split(",") {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3", 3);
        populate_pickups(world, level, game_directory("q3"));
        populate_opponents(world, level, game_directory("q3"));
        prepare_arena_links(world, level.collision);
        mesh = [world->:HasNavMesh:->][?:NavMesh][0];
        items = bot_items(world);
        contest = match_of(world);
        assert items is not None and contest is not None;
        contest.warmup = 0.0;
        bots = [bot for bot in [world->:HasOpponent:->][?:Opponent] if bot.arena];
        bot = bots[0];
        for other in bots[1:] {
            other.dormant = True;
        }
        # Where a bot may stand and where it may be sent: spawn points and items.
        spots: list[tuple[Vec3, int]] = [];
        for entity in level.bsp.entities {
            if entity.fields.get("classname", "") == "info_player_deathmatch" {
                parts = entity.fields.get("origin", "0 0 0").split();
                spot = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
                landing = level.collision.trace(spot.add(Vec3(z=16.0)), spot.sub(Vec3(z=512.0)));
                if not landing.start_solid {
                    spots.append((landing.end, mesh.locate(landing.end)));
                }
            }
        }
        for item in [items->:HasLevelItem:->][?:LevelItem] {
            # Where a player stands to have the item: its box set down there.
            landing = level.collision.trace(item.goal_origin.add(Vec3(z=40.0)), item.goal_origin.sub(Vec3(z=64.0)));
            if item.goal_area > 0 and not landing.start_solid and mesh.locate(landing.end) == item.goal_area {
                spots.append((landing.end, item.goal_area));
            }
        }
        # The doors something else opens: those with a targetname or health.
        doors: list[int] = [];
        for entity in level.bsp.entities {
            fields = entity.fields;
            if fields.get("classname", "") == "func_door"
                and (fields.get("targetname", "") or float(fields.get("health", "0")) != 0.0) {
                doors.append(brush_model(fields));
            }
        }
        print(name + ": " + str(len(doors)) + " doors to be opened " + str(["*" + str(model) for model in doors]));
        player = Player(health=0, pos=Vec3(z=-100000.0));
        far = Vec3(z=-100000.0);
        state = CombatState(game="q3");
        equip_player(player, state, "q3");
        contacts = ArenaContactIndex();
        for model in doors {
            # The shortest way between two spots that runs into this door.
            best_time = 0;
            start = Vec3();
            goal: tuple[Vec3, int] | None = None;
            for origin in spots {
                for target in spots {
                    if origin[1] == target[1] or origin[1] == 0 {
                        continue;
                    }
                    mesh.times_to(target[1]);
                    if predict_mover(mesh, origin[1], origin[0], target[1], TFL_DEFAULT) != model {
                        continue;
                    }
                    t = area_travel_time(mesh, origin[1], origin[0], target[1]);
                    if t > 0 and (goal is None or t < best_time) {
                        best_time = t;
                        start = origin[0];
                        goal = target;
                    }
                }
            }
            if goal is None {
                print("  *" + str(model) + ": on no route between spawn points and items");
                continue;
            }
            # Let every door shut again before the try.
            for tick in range(int(12.0 / dt)) {
                world spawn SignalTick(dt=dt, inventory=player.inventory);
                world spawn DoorTick(bsp=level.bsp, collision=level.collision, player_origin=far, dt=dt, touching=False);
            }
            if verbose {
                probe = world spawn FindActivator(
                    model=model, bsp=level.bsp, collision=level.collision, mesh=mesh, origin=start,
                    eye=start.add(Vec3(z=bot.eye_height)), area=mesh.locate(start), flags=TFL_DEFAULT, now=0.0
                );
                print("    activator: entity " + str(probe.entity) + " model *" + str(probe.found.entity) + " shoot " + str(probe.found.shoot)
                    + " goal area " + str(probe.found.goal.area) + " door areas " + str(probe.found.areas) + " closed " + str(sorted(list(mesh.disabled))));
                probe.found.enable_areas(mesh, True);
                for leader in [world->:HasDoor:->][?:Door] {
                    print("    door *" + str(leader.model) + " " + leader.kind + " signal " + str(leader.activation.entities)
                        + " fired by " + str([source.entities for source in [leader.activation<-:Targets:<-][?:Signal]]));
                }
            }
            bot.pos = start.add(Vec3(z=bot.eye_height + 1.0));
            bot.velocity = Vec3();
            bot.grounded = False;
            bot.rest_serial = -1;
            bot.health = 100;
            bot.bot_state = BotState();
            bot.route = [];
            bot.route_areas = [];
            went = "";
            opened = -1.0;
            passed = -1.0;
            for tick in range(int(seconds / dt)) {
                memory = bot.bot_state;
                top = memory.goals.top();
                if top is None or top.area != goal[1] {
                    memory.goals.empty();
                    memory.goals.push(BotGoal(origin=goal[0], area=goal[1]));
                    memory.ltg_time = 100000.0;
                }
                world spawn SignalTick(dt=dt, inventory=player.inventory);
                world spawn DoorTick(bsp=level.bsp, collision=level.collision, player_origin=far, dt=dt, touching=False);
                world spawn TriggerTick(player=player, start=far, finish=far, dt=dt, touching=False);
                world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt);
                world spawn ImmerseBots(level=level, dt=dt);
                world spawn CombatTick(player=player, collision=level.collision, state=state, dt=dt, arena_live=True);
                world spawn BotTactics(player=player, collision=level.collision, state=state, rules=state.rules, dt=dt, map_name=name, level=level);
                world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=dt);
                for impact in state.impacts {
                    if impact.model >= 0 {
                        world spawn ShootMover(model=impact.model, amount=impact.amount);
                    }
                }
                state.impacts = [];
                world spawn ArenaNavigationTick(collision=level.collision, index=contacts, dt=dt, contacts=True);
                task = memory.obstacles.top();
                if task is not None and not went {
                    went = ("shoot *" if task.shoot else "touch *") + str(task.entity) + " from area " + str(task.goal.area);
                }
                if verbose and tick % 480 == 0 {
                    feet = bot.pos.sub(Vec3(z=bot.eye_height));
                    print("    t=" + str(round(float(tick) * dt, 1)) + " " + memory.ainode + " at " + str([int(feet.x), int(feet.y), int(feet.z)])
                        + " area " + str(mesh.locate(feet)) + " route " + str(len(bot.route))
                        + (" blocked by *" + str(memory.travel.block_model) if memory.travel.blocked else "")
                        + (" task *" + str(task.entity) + " until " + str(round(task.time - memory.clock, 1)) if task is not None else "")
                        + " closed " + str(sorted(list(mesh.disabled))));
                    leg = memory.route.passages[0] if memory.route.passages else None;
                    if leg is not None {
                        print("      leg kind " + str(leg.kind) + " from " + str([int(leg.start.x), int(leg.start.y), int(leg.start.z)])
                            + " to " + str([int(leg.finish.x), int(leg.finish.y), int(leg.finish.z)]) + " into area " + str(leg.target)
                            + " mover " + str(leg.mover) + " model " + str(leg.model) + " grounded " + str(bot.grounded));
                    }
                }
                if opened < 0.0 and not door_shut(world, model) {
                    opened = float(tick) * dt;
                }
                if task is None and mesh.locate(bot.pos.sub(Vec3(z=bot.eye_height))) == goal[1] {
                    passed = float(tick) * dt;
                    break;
                }
            }
            print("  *" + str(model) + ": " + str(best_time) + " hundredths from " + str([int(start.x), int(start.y), int(start.z)])
                + " to area " + str(goal[1]) + "; went to " + (went if went else "nothing")
                + "; door opened " + (str(round(opened, 1)) + " s" if opened >= 0.0 else "never")
                + "; goal reached " + (str(round(passed, 1)) + " s" if passed >= 0.0 else "never"));
            if passed < 0.0 {
                failures.append(name + " *" + str(model));
            }
        }
    }
    print("BOT OBSTACLES " + ("ok" if not failures else "failed: " + str(failures)));
    assert not failures;
}
