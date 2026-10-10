"""Walk Q3's single-player ladder through the real game loop.

Each arena is loaded as the menu loads it and played for QP_SECONDS (default
20) of frames with the player idle in god mode, so the bots fight each
other. Then the player is given the frag limit: the match must end, the
podium and postgame must start, and leaving the postgame must load the next
arena along the ladder. Frame times, bot frags and how far the bots moved
are printed per arena, with any problems at the end.

Build natively and run from the repo root:
    jac build scripts/arena_ladder_walkthrough.jac --native -o .jac/ladder
    DYLD_LIBRARY_PATH=vendor .jac/ladder      # QP_LADDER_ONLY=q3dm7,q3dm12 limits it

Frames are a sixtieth of a second of game time each (QP_WALK_DT sets another
step; 0 uses the renderer's frame time).
"""
import os;
import time;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.arena { ArenaMatch, Competes, match_of, standings, competitor_name }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.bot_routes { NavMesh, HasNavMesh, Passage, Exits, area_travel_time }
import from engine.world.bot_goals { BotItems, HasBotItems, LevelItem, HasLevelItem }
import from engine.world.pickups { Pickup, HasPickup }
import from engine.world.bot_travel { mover_box, on_mover, bob_position }
import from engine.physics.collision { CollisionMap }
import from engine.assets.library { AssetLibrary }
import from games.arenas { load_arenas, ladder }
import from engine.math.vec3 { Vec3 }

"""Where the mover of a bot's leg is and whether the bot is on it: the
mover's place along its axis between the leg's near and far ends."""
def mover_note(world: World, collision: CollisionMap, leg: Passage, origin: Vec3, grounded: bool) -> str {
    meshes = [world->:HasNavMesh:->][?:NavMesh];
    box = mover_box(meshes[0], collision, leg.model) if meshes else None;
    if box is None {
        return "no mover";
    }
    return ("on" if on_mover(collision, box, leg.model, origin) else "off") + (" ground " if grounded else " air ")
        + str([int(origin.x), int(origin.y), int(origin.z)]) + " mover at " + str(int(bob_position(box, leg.axis)))
        + " of " + str(int(leg.near)) + ".." + str(int(leg.far)) + " top " + str(int(box.maxs.z));
}

"""Why a bot has no item to go for (BotChooseLTGItem): the ways out of its
area by travel type, and how many of the level's items are placed in an
area, weigh anything to it, can be reached from where it stands with its
travel flags, are both, and of those are not still avoided."""
def idle_items(world: World, bot: Opponent) -> str {
    meshes = [world->:HasNavMesh:->][?:NavMesh];
    stores = [world->:HasBotItems:->][?:BotItems];
    mind = bot.character;
    if not meshes or not stores or mind is None {
        return "no items";
    }
    mesh = meshes[0];
    memory = bot.bot_state;
    origin = bot.pos.sub(Vec3(z=bot.eye_height));
    area = mesh.locate(origin);
    total = 0;
    placed = 0;
    wanted = 0;
    reachable = 0;
    both = 0;
    free = 0;
    for item in [stores[0]->:HasLevelItem:->][?:LevelItem] {
        total += 1;
        if not item.linked or item.goal_area == 0 {
            continue;
        }
        placed += 1;
        number = mind.item_numbers.get(item.info.classname, -1);
        weight = mind.item_weights.undecided(memory.inventory, number, memory.dice) if number >= 0 else 0.0;
        t = area_travel_time(mesh, area, origin, item.goal_area, memory.travel_flags);
        if weight > 0.0 {
            wanted += 1;
        }
        if t > 0 {
            reachable += 1;
        }
        if weight > 0.0 and t > 0 {
            both += 1;
            if memory.goals.avoid_time(item.number, stores[0].clock) - float(t) * 0.009 <= 0.0 {
                free += 1;
            }
        }
    }
    ways = [(leg.kind, leg.target) for leg in [mesh.areas[area]->:Exits:->][?:Passage]];
    return "ways out (travel type, area) " + str(ways) + " travel flags " + str(memory.travel_flags) + " last area "
        + str(memory.goals.last_area) + " items " + str(total) + " placed " + str(placed) + " wanted " + str(wanted)
        + " reachable " + str(reachable) + " both " + str(both) + " not avoided " + str(free);
}

"""How many of the map's pickups the bots know as level items with a goal
area (BotInitLevelItems)."""
def level_items(world: World) -> str {
    stores = [world->:HasBotItems:->][?:BotItems];
    known = 0;
    if stores {
        for item in [stores[0]->:HasLevelItem:->][?:LevelItem] {
            if item.goal_area != 0 {
                known += 1;
            }
        }
    }
    return str(known) + " of " + str(len([world->:HasPickup:->][?:Pickup]));
}

"""The AAS area a bot stands in and how many reachabilities lead out of it
(a bot in an area with none has nowhere to go)."""
def idle_area(world: World, origin: Vec3) -> str {
    meshes = [world->:HasNavMesh:->][?:NavMesh];
    if not meshes {
        return "no AAS";
    }
    area = meshes[0].locate(origin);
    return str(area) + " with " + str(meshes[0].aas.areas[area].reach_count) + " reachabilities";
}

"""Arena names in ladder order."""
def ladder_names -> list[str] {
    library = AssetLibrary(game="q3");
    names: list[str] = [];
    try {
        library.open(game_directory("q3"));
        for arena in ladder(load_arenas(library)) {
            names.append(arena.map);
        }
    } finally {
        library.close();
    }
    return names;
}

"""Total frags scored by bots so far."""
def bot_frags(contest: ArenaMatch) -> int {
    total = 0;
    for row in standings(contest) {
        if not row.human {
            total += row.frags;
        }
    }
    return total;
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True);
    app.host.overlay.assign("0");
    names = ladder_names();
    only = os.getenv("QP_LADDER_ONLY", "");
    if only {
        names = [name for name in names if name in only.split(",")];
    }
    frames = int(float(os.getenv("QP_SECONDS", "20")) * 60.0);
    # Each frame is a sixtieth of a second of game time, so QP_SECONDS are
    # seconds of play whatever pace the display sets (a hidden window is not
    # held to the refresh rate). QP_WALK_DT=0 plays at the renderer's own
    # frame time.
    app.fixed_dt = float(os.getenv("QP_WALK_DT", str(1.0 / 60.0)));
    problems: list[str] = [];
    app.load_destination("q3", names[0]);
    if not app.audio.ready {
        app.audio.open("q3", game_directory("q3"));
    }
    app.audio.volume.assign("0");
    app.smoke = False;
    app.walking = True;
    for name in names {
        try {
            app.load_destination("q3", name);
        } except Exception as error {
            problems.append(name + ": load failed: " + str(error));
            print("LADDER", name, "LOAD FAILED", error);
            continue;
        }
        if app.level.name != name {
            problems.append(name + ": did not load");
            continue;
        }
        app.player.god_mode = True;
        app.skip_time = True;
        contest = match_of(app.world);
        if contest is None {
            problems.append(name + ": no match");
            continue;
        }
        # Skip the warmup countdown: the bots fight from the first frame.
        contest.warmup = 0.0;
        bots = [app.world->:HasOpponent:->][?:Opponent];
        starts: list[Vec3] = [bot.pos.add(Vec3()) for bot in bots];
        travelled: list[float] = [0.0 for bot in bots];
        times: list[float] = [];
        # What each bot dies of and what it spends its time on (the AI node
        # it is in, frame by frame), for the deaths and idle bots reported.
        alive: list[bool] = [bot.health > 0 for bot in bots];
        nodes: list[dict[str, int]] = [{} for bot in bots];
        # Where each bot last stood and what it was doing there: the travel
        # type of its leg (0 with none), or -1 for a fight's own moves.
        stood: list[Vec3] = [bot.pos.add(Vec3()) for bot in bots];
        doing: list[int] = [0 for bot in bots];
        # How it left the ground after that: its velocity on the first frame
        # in the air (270 up is a jump, a few units down a step off an edge,
        # anything else a push) and the health it had lost by then.
        leaving: list[Vec3] = [Vec3() for bot in bots];
        hurt: list[int] = [0 for bot in bots];
        stood_health: list[int] = [bot.health for bot in bots];
        # What moved it there: its AI node, its steering, the travel's own
        # direction and speed, a sidestep round an obstacle, and whether its
        # route was being followed (the three lists agree).
        moving: list[str] = ["" for bot in bots];
        airborne: list[bool] = [False for bot in bots];
        waited: list[int] = [0 for bot in bots];
        # A bot on a mover's leg: its last second there, six times a second.
        rides: list[list[str]] = [[] for bot in bots];
        aimless: list[int] = [0 for bot in bots];
        for i in range(frames) {
            started = time.time();
            app.step();
            times.append((time.time() - started) * 1000.0);
            for j in range(len(bots)) {
                bot = bots[j];
                memory = bot.bot_state;
                state = memory.ainode;
                nodes[j][state] = nodes[j].get(state, 0) + 1;
                leg = memory.route.passages[0] if memory.route.passages else None;
                if bot.grounded and bot.health > 0 {
                    stood[j] = bot.pos.sub(Vec3(z=bot.eye_height));
                    doing[j] = -1 if bot.fighting else (leg.kind if leg is not None else 0);
                    stood_health[j] = bot.health;
                    airborne[j] = False;
                    detour = memory.detour;
                    moving[j] = state + " steering " + str([round(bot.steering.x, 2), round(bot.steering.y, 2)]) + " travel "
                        + str([round(memory.travel.direction.x, 2), round(memory.travel.direction.y, 2)]) + " at "
                        + str(int(memory.travel.speed)) + (" sidestep " + str([round(detour.x, 2), round(detour.y, 2)]) if detour is not None else "")
                        + " route " + str([len(bot.route), len(bot.route_areas), len(memory.route.points)])
                        + " speed " + str(int(Vec3(x=bot.velocity.x, y=bot.velocity.y).length()));
                } elif bot.health > 0 and not airborne[j] {
                    airborne[j] = True;
                    leaving[j] = bot.velocity.add(Vec3());
                    hurt[j] = stood_health[j] - bot.health;
                }
                if memory.travel.waiting {
                    waited[j] += 1;
                }
                if leg is not None and leg.model > 0 and bot.health > 0 and i % 10 == 0 {
                    rides[j].append(
                        mover_note(app.world, app.level.collision, leg, bot.pos.sub(Vec3(z=bot.eye_height)), bot.grounded)
                    );
                    if len(rides[j]) > 6 {
                        rides[j].pop(0);
                    }
                }
                if bot.arena_goal is None and not bot.fighting {
                    aimless[j] += 1;
                }
                if alive[j] and bot.health <= 0 {
                    killer = bot.killer;
                    feet = bot.pos.sub(Vec3(z=bot.eye_height));
                    print("LADDER", name, "death", competitor_name(contest, bot), "at", round(float(i) / 60.0, 1), "s means",
                        bot.death_means if bot.death_means else "none", "by",
                        (competitor_name(contest, killer) or "the player") if killer is not None else "the world",
                        "at", [int(feet.x), int(feet.y), int(feet.z)], "velocity",
                        [int(bot.velocity.x), int(bot.velocity.y), int(bot.velocity.z)], "node", state,
                        "weapon", bot.weapon_slot, "last stood at", [int(stood[j].x), int(stood[j].y), int(stood[j].z)],
                        "doing", doing[j], "left the ground at",
                        [int(leaving[j].x), int(leaving[j].y), int(leaving[j].z)], "having lost", hurt[j], "health;", moving[j], "leg from", [int(leg.start.x), int(leg.start.y), int(leg.start.z)] if leg is not None else [],
                        "to", [int(leg.finish.x), int(leg.finish.y), int(leg.finish.z)] if leg is not None else [],
                        "on the mover", rides[j]);
                }
                alive[j] = bot.health > 0;
            }
            if i % 30 == 29 {
                for j in range(len(bots)) {
                    travelled[j] += bots[j].pos.sub(starts[j]).length();
                    starts[j] = bots[j].pos.add(Vec3());
                }
            }
        }
        ordered = sorted(times);
        median = ordered[len(ordered) // 2];
        worst = ordered[-1];
        frags = bot_frags(contest);
        idle = len([d for d in travelled if d < 64.0]);
        for j in range(len(bots)) {
            mind = bots[j].character;
            if travelled[j] < 64.0 and mind is not None {
                print("LADDER", name, "idle", competitor_name(contest, bots[j]), "moved", int(travelled[j]), "nodes",
                    nodes[j], "attack skill", mind.attack_skill, "jumper", mind.jumper, "croucher", mind.croucher,
                    "weapon", bots[j].weapon_slot, "health", bots[j].health, "frames waiting for a mover", waited[j],
                    "frames with no goal", aimless[j], "leg", doing[j], "at", [int(stood[j].x), int(stood[j].y), int(stood[j].z)],
                    "area", idle_area(app.world, stood[j]), idle_items(app.world, bots[j]));
            }
        }
        print("LADDER", name, "bots", len(bots), "median ms", round(median, 1), "worst ms", round(worst, 1), "bot frags", frags, "idle bots", idle,
            "level items", level_items(app.world));
        if median > 25.0 {
            problems.append(name + ": median frame " + str(round(median, 1)) + " ms");
        }
        if bots and idle == len(bots) {
            problems.append(name + ": no bot moved");
        }
        # The player has the frag limit: the exit rules, checked every tick
        # (CheckExitRules), end the match into the podium. Should that not
        # happen in time, the podium is started directly and reported as
        # forced.
        for score in [edge contest->:Competes:->] {
            if score.human {
                score.frags = contest.fraglimit;
            }
        }
        how = "by frag";
        for i in range(frames) {
            app.step();
            if app.postgame is not None {
                break;
            }
        }
        if app.postgame is None {
            how = "forced";
            contest.finished = True;
            app.begin_podium(contest);
        }
        if app.postgame is None {
            problems.append(name + ": no postgame");
            continue;
        }
        expected = next_arena_name(names, name);
        app.finish_arena(contest);
        print("LADDER", name, "ended", how, "-> next", app.level.name, "(expected", expected + ")");
        if expected and app.level.name != expected {
            problems.append(name + ": left for " + app.level.name + ", expected " + expected);
        }
    }
    print("LADDER PROBLEMS", len(problems));
    for problem in problems {
        print("LADDER PROBLEM", problem);
    }
    renderer.close();
}

"""The arena after `name` in `names`, or "" at the end of the ladder."""
def next_arena_name(names: list[str], name: str) -> str {
    for i in range(len(names) - 1) {
        if names[i] == name {
            return names[i + 1];
        }
    }
    return "";
}
