"""Original Q3 maps: parse the AAS, set up the level items bots go for
(BotInitLevelItems, with jump pad goals for floating items), and plan routes
between every pair of spawn points and item goals, with TFL_DEFAULT and with
rocket jumps. Counts the routes that take a rocket jump or ride a mover."""
import time;
import from engine.core.menu { game_directory }
import from engine.assets.library { AssetLibrary }
import from engine.formats.aas { parse_aas, TFL_DEFAULT, TFL_ROCKETJUMP, TRAVEL_ROCKETJUMP, TRAVEL_FUNCBOB, TRAVEL_ELEVATOR }
import from engine.world.world { World }
import from engine.world.level { load_level }
import from engine.world.bot_routes { build_navmesh, plan_route }
import from engine.world.bot_goals { BotItems, HasBotItems, LevelItem, HasLevelItem }
import from engine.world.arena_navigation { prepare_arena_links }
import from engine.math.vec3 { Vec3 }
import from games.items { populate_pickups }
import from games.botfiles { BotFiles }

with entry {
    library = AssetLibrary(game="q3");
    library.open(game_directory("q3"));
    infos = BotFiles(library=library).item_config();
    for name in ["q3dm1", "q3dm7", "q3dm17", "q3tourney2", "q3dm19", "q3dm14", "q3tourney6"] {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3");
        populate_pickups(world, level, game_directory("q3"));
        began = time.time();
        aas = parse_aas(library.read("maps/" + name + ".aas"));
        mesh = build_navmesh(world, aas, level.bsp);
        items = BotItems(infos=infos);
        world +>:HasBotItems:+> items;
        prepare_arena_links(world, level.collision);
        built = time.time();
        # Where bots start (players drop from spawn points to the floor) and
        # the goals of the items they go for.
        points: list[Vec3] = [];
        areas: list[int] = [];
        # A floating item's goal is the jump pad throwing bots through it: a
        # place to go, not one to set off from.
        starts: list[bool] = [];
        for entity in level.bsp.entities {
            if entity.fields.get("classname", "") != "info_player_deathmatch" {
                continue;
            }
            parts = entity.fields.get("origin", "0 0 0").split();
            spot = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            landing = level.collision.trace(spot.add(Vec3(z=16.0)), spot.sub(Vec3(z=512.0)));
            if not landing.start_solid and landing.fraction < 1.0 {
                spot = landing.end;
            }
            points.append(spot);
            areas.append(mesh.locate(spot));
            starts.append(True);
        }
        spawns = len(points);
        goals = [item for item in [items->:HasLevelItem:->][?:LevelItem]];
        for item in goals {
            points.append(item.goal_origin);
            areas.append(item.goal_area);
            starts.append(mesh.locate(item.goal_origin) == item.goal_area);
        }
        located = len([area for area in areas if area > 0]);
        # Bots build their travel tables in the background; here, up front.
        for area in areas {
            if area > 0 {
                mesh.times_to(area);
                mesh.times_to(area, TFL_DEFAULT | TFL_ROCKETJUMP);
            }
        }
        names: list[str] = ["spawn" for i in range(spawns)] + [item.info.classname for item in goals];
        planned = 0;
        jumped = 0;
        rocket_routes = 0;
        mover_routes = 0;
        tried = 0;
        # Goals the AAS joins to nothing, which bots never choose (their
        # travel time is 0), are reported and left out.
        stranded: list[str] = [];
        for b in range(len(points)) {
            misses = 0;
            sources = 0;
            for a in range(len(points)) {
                if a == b or not starts[a] or areas[a] == 0 or areas[b] == 0 or areas[a] == areas[b] {
                    continue;
                }
                sources += 1;
                if not plan_route(mesh, points[a], points[b], 256, TFL_DEFAULT | TFL_ROCKETJUMP, areas[b]).found {
                    misses += 1;
                }
            }
            if sources > 0 and misses == sources {
                stranded.append(names[b]);
                continue;
            }
            for a in range(len(points)) {
                if a == b or not starts[a] or areas[a] == 0 or areas[b] == 0 or areas[a] == areas[b] {
                    continue;
                }
                tried += 1;
                route = plan_route(mesh, points[a], points[b], 256, TFL_DEFAULT, areas[b]);
                if route.found {
                    planned += 1;
                    if any([p is not None and p.kind in [TRAVEL_FUNCBOB, TRAVEL_ELEVATOR] for p in route.passages]) {
                        mover_routes += 1;
                    }
                }
                # With a rocket launcher, rockets and health to spare.
                jumping = plan_route(mesh, points[a], points[b], 256, TFL_DEFAULT | TFL_ROCKETJUMP, areas[b]);
                if jumping.found {
                    jumped += 1;
                    if any([p is not None and p.kind == TRAVEL_ROCKETJUMP for p in jumping.passages]) {
                        rocket_routes += 1;
                    }
                }
            }
        }
        done = time.time();
        print(
            "AAS " + name + " areas " + str(len(aas.areas)) + " reaches " + str(len(aas.reaches))
                + " spawns " + str(spawns) + " item goals " + str(len(goals))
                + " located " + str(located) + "/" + str(len(points))
                + " routes " + str(planned) + "/" + str(tried)
                + " with rocket jumps " + str(jumped) + "/" + str(tried)
                + " (" + str(rocket_routes) + " jump)"
                + " riding movers " + str(mover_routes)
                + " stranded " + str(stranded)
                + " setup " + str(round(built - began, 2)) + "s plan " + str(round(done - built, 2)) + "s"
        );
        assert located == len(points);
        # With rocket jumps every goal is in reach; on q3dm17 some only with them.
        assert jumped == tried;
        assert planned == tried or name == "q3dm17";
    }
    library.close();
}
