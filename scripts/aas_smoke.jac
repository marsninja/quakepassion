"""Original Q3 maps: parse the AAS, locate spawn points and plan routes between
every pair of spawns and items."""
import time;
import from engine.core.menu { game_directory }
import from engine.assets.library { AssetLibrary }
import from engine.formats.aas { parse_aas }
import from engine.formats.bsp { parse_entities }
import from engine.world.world { World }
import from engine.world.level { load_level }
import from engine.world.bot_routes { build_navmesh, plan_route }
import from engine.math.vec3 { Vec3 }

with entry {
    for name in ["q3dm1", "q3dm7", "q3dm17", "q3tourney2"] {
        world = World();
        level = load_level(world, game_directory("q3"), name, "q3");
        library = AssetLibrary(game="q3");
        library.open(game_directory("q3"));
        began = time.time();
        aas = parse_aas(library.read("maps/" + name + ".aas"));
        parsed = time.time();
        mesh = build_navmesh(world, aas);
        built = time.time();
        library.close();
        spots: list[Vec3] = [];
        for entity in level.bsp.entities {
            kind = entity.fields.get("classname", "");
            if kind == "info_player_deathmatch" or kind.startswith("weapon_") or kind.startswith("item_") {
                parts = entity.fields.get("origin", "0 0 0").split();
                spot = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
                # Where a bot stands there: players drop from spawn points to the floor.
                landing = level.collision.trace(spot.add(Vec3(z=16.0)), spot.sub(Vec3(z=512.0)));
                if not landing.start_solid and landing.fraction < 1.0 {
                    spot = landing.end;
                }
                spots.append(spot);
            }
        }
        located = len([spot for spot in spots if mesh.locate(spot) > 0]);
        planned = 0;
        tried = 0;
        passages = 0;
        for a in spots {
            for b in spots {
                if a is b or mesh.locate(a) == 0 or mesh.locate(b) == 0 {
                    continue;
                }
                tried += 1;
                route = plan_route(mesh, a, b, 256);
                if route.found {
                    planned += 1;
                    passages += len(route.points);
                }
            }
        }
        done = time.time();
        print("AAS", name, "areas", len(aas.areas), "reaches", len(aas.reaches),
            "spots", len(spots), "located", located, "routes", planned, "/", tried,
            "points", passages, "parse", parsed - began, "build", built - parsed,
            "plan", done - built, "tables", len(mesh.tables));
        assert located * 10 >= len(spots) * 9;
        # q3dm17's floating platforms are partly reachable only by rocket jumps,
        # which bots without a rocket launcher cannot use there either.
        if name == "q3dm17" {
            assert planned * 2 >= tried;
        } else {
            assert planned == tried;
        }
    }
}
