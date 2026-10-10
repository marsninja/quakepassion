"""What closed area portals cull, measured on original maps (no window).

Each map is loaded with its monsters and items. From the player's start and
from four points around every door that holds an area portal, the world
faces `Level.visible` returns and the models `GatherModels` collects are
counted three ways: by the PVS alone (every portal open), with every portal
shut as the level starts, and with only the nearest door open. The report
gives the start's counts and the door where shutting the portals saves most.

    jac build scripts/area_portal_smoke.jac --native -o .jac/area-portal-smoke
    DYLD_LIBRARY_PATH=vendor .jac/area-portal-smoke

QP_PORTAL_MAPS=q2:bunk1,q3:q3dm12 chooses the maps.
"""
import os;
import from engine.world.level { Level, load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.models { GatherModels }
import from engine.world.doors { Door, HasDoor }
import from engine.world.area_portals { AreaPortalTick, OpensPortal, HasAreaPortal }
import from engine.world.map_areas { AreaPortal }
import from engine.core.menu { game_directory }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from engine.formats.bsp { model_bounds, mover_origin }
import from engine.math.vec3 { Vec3 }

"""World faces and models drawn from `eye`."""
def drawn(level: Level, world: World, eye: Vec3) -> tuple[int, int] {
    limit = level.bsp.models[0].face_count;
    faces = len([face for face in level.visible(world, eye, True) if face < limit]);
    return (faces, len((world spawn GatherModels()).draws));
}

"""Hold these portal doors open or let them rest, and flood."""
def set_doors(world: World, doors: list[Door], open: bool) {
    for door in doors {
        door.state = "open" if open else "closed";
    }
    world spawn AreaPortalTick();
}

"""Open or shut every portal: the doors', and the ones relays toggle."""
def set_portals(world: World, portals: list[AreaPortal], doors: list[Door], open: bool) {
    for portal in portals {
        portal.toggled = open;
    }
    set_doors(world, doors, open);
}

with entry {
    chosen = os.getenv("QP_PORTAL_MAPS", "q2:base1,q2:bunk1,q2:jail4,q2:ware1,q2:command,q3:q3dm0,q3:q3dm11,q3:q3dm12");
    for entry_name in chosen.split(",") {
        game = entry_name.split(":")[0];
        name = entry_name.split(":")[1];
        world = World();
        level = load_level(world, game_directory(game), name, game);
        player = spawn_player(level);
        populate_pickups(world, level, game_directory(game));
        populate_opponents(world, level, game_directory(game));
        chart = level.area_map;
        assert chart is not None , name;
        portals = [world->:HasAreaPortal:->][?:AreaPortal];
        doors: list[Door] = [];
        for portal in portals {
            for door in [portal<-:OpensPortal:<-][?:Door] {
                if door not in doors {
                    doors.append(door);
                }
            }
        }
        eye = player.pos;
        set_portals(world, portals, doors, True);
        pvs = drawn(level, world, eye);
        set_portals(world, portals, doors, False);
        shut = drawn(level, world, eye);
        print(
            "AREAS", game, name, "areas", len(chart.areas) - chart.first, "portals", len(portals),
            "doors", len(doors), "| start: faces", pvs[0], "->", shut[0], "models", pvs[1], "->", shut[1]
        );
        best_saving = -1;
        best = "";
        for door in doors {
            if door.entity < 0 or door.model <= 0 {
                continue;
            }
            centre = model_bounds(level.bsp, door.model, mover_origin(level.bsp.entities[door.entity].fields)).center();
            for offset in [Vec3(x=96.0), Vec3(x=-96.0), Vec3(y=96.0), Vec3(y=-96.0)] {
                probe = centre.add(offset);
                leaf = level.bsp.leaves[level.locate(probe)];
                if leaf.cluster < 0 or chart.area(leaf.area) is None {
                    continue;
                }
                set_doors(world, [door], True);
                through = drawn(level, world, probe);
                set_doors(world, [door], False);
                closed = drawn(level, world, probe);
                if through[0] - closed[0] > best_saving {
                    best_saving = through[0] - closed[0];
                    best = "door *" + str(door.model) + " at " + str(int(probe.x)) + " " + str(int(probe.y)) + " " + str(int(probe.z))
                        + ": faces open " + str(through[0]) + " shut " + str(closed[0])
                        + ", models open " + str(through[1]) + " shut " + str(closed[1]);
                }
            }
        }
        if best {
            print("AREAS", game, name, best);
        }
    }
    print("AREA PORTAL SMOKE PASSED");
}
