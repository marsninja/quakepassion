"""The router's view of a level graph: the flat AAS arrays the bots route
over (`engine/world/bot_routes.jac`), compiled from the graph's places and
moves, so a bot plays by the graph the proof read.

A graph read off a level's compiled navigation locates its places by a tree
built over their boxes (as the compiler builds one); a graph imported from a
level's shipped AAS file (Quake III's) keeps that file's own tree, whose
areas are its places."""
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }
import from ..formats.aas { Aas, AasArea, AasReach, PRESENCE_NORMAL, AREACONTENTS_MOVER, AREACONTENTS_MODELNUMSHIFT, TRAVEL_ELEVATOR }
import from ..world.world { World }
import from ..world.level { Level }
import from ..world.bot_routes { NavMesh, HasNavMesh, build_navmesh }
import from ..nav.compile { NavTree }
import from .graph { LevelGraph, Place, Move, Holds, graph_places }
import from .extract { ReadOptions, read_level_graph }

"""The AAS arrays of a graph: an area for each place (by its number), the
moves a router follows (all but the falls run to find traps) as
reachabilities, and the tree that locates the areas (the source file's,
when the graph was imported from one)."""
def graph_aas(atlas: LevelGraph, tree_from: Aas | None = None) -> Aas {
    aas = Aas();
    places = graph_places(atlas);
    count = max([place.area for place in places] + [0]) + 1;
    by_area: list[Place | None] = [None for _ in range(count)];
    for place in places {
        by_area[place.area] = place;
    }
    aas.areas.append(AasArea(center=Vec3(), mins=Vec3(), maxs=Vec3()));
    aas.reaches.append(AasReach(area=0, start=Vec3(), finish=Vec3(), kind=0, time=0));
    boxes: list[AABB] = [AABB(mins=Vec3(), maxs=Vec3())];
    for area in range(1, count) {
        place = by_area[area];
        if place is None {
            aas.areas.append(AasArea(center=Vec3(), mins=Vec3(), maxs=Vec3()));
            boxes.append(AABB(mins=Vec3(x=1.0e9, y=1.0e9, z=1.0e9), maxs=Vec3(x=1.0e9, y=1.0e9, z=1.0e9)));
            continue;
        }
        info = AasArea(center=place.center, mins=place.box.mins, maxs=place.box.maxs, flags=place.flags, contents=place.contents, presence=PRESENCE_NORMAL);
        info.first_reach = len(aas.reaches);
        for move in [edge place->:Move:->] {
            if move.fall or move.to <= 0 {
                continue;
            }
            aas.reaches.append(
                AasReach(area=move.to, start=move.start, finish=move.finish, kind=move.kind, time=move.time, face_num=move.model if move.kind == TRAVEL_ELEVATOR else 0)
            );
        }
        info.reach_count = len(aas.reaches) - info.first_reach;
        aas.areas.append(info);
        boxes.append(place.box);
    }
    if tree_from is not None {
        aas.normals = tree_from.normals;
        aas.dists = tree_from.dists;
        aas.node_planes = tree_from.node_planes;
        aas.front = tree_from.front;
        aas.back = tree_from.back;
        return aas;
    }
    aas.normals.append(Vec3(z=1.0));
    aas.dists.append(-1000000.0);
    aas.node_planes = [0, 0];
    aas.front = [0, 0];
    aas.back = [0, 0];
    tree = NavTree(aas=aas, boxes=boxes);
    live = [area for area in range(1, count) if by_area[area] is not None];
    top = tree.build(live);
    aas.front[1] = top;
    aas.back[1] = top;
    return aas;
}

"""A graph imported from a level's shipped AAS file: its areas the places,
its reachabilities the moves (all sure: the game's own compiler found
them)."""
def graph_from_aas(aas: Aas, level: Level) -> LevelGraph {
    atlas = LevelGraph(name=level.name, game=level.bsp.game);
    atlas.notes.append("imported from the level's AAS file: " + str(len(aas.areas) - 1) + " areas");
    places: list[Place] = [Place(area=0)];
    for index in range(1, len(aas.areas)) {
        info = aas.areas[index];
        place = Place(area=index, center=info.center, box=AABB(mins=info.mins, maxs=info.maxs), flags=info.flags, contents=info.contents);
        place.floor = info.mins.z;
        if info.contents & AREACONTENTS_MOVER != 0 {
            place.mover = info.contents >> AREACONTENTS_MODELNUMSHIFT;
        }
        places.append(place);
        atlas +>:Holds:+> place;
    }
    for index in range(1, len(aas.areas)) {
        info = aas.areas[index];
        for r in range(info.first_reach, info.first_reach + info.reach_count) {
            reach = aas.reaches[r];
            if 0 < reach.area < len(places) {
                places[index] +>:Move(
                    kind=reach.kind,
                    to=reach.area,
                    model=reach.face_num & 65535 if reach.kind == TRAVEL_ELEVATOR else 0,
                    start=reach.start,
                    finish=reach.finish,
                    time=reach.time
                ):+> places[reach.area];
            }
        }
    }
    return atlas;
}

"""What a bot routes a level by: the map's own AAS file brought in as a
graph when it shipped one, else the level's graph read from its compiled
navigation. Answers the graph and the router's mesh over it."""
def level_routes(world: World, level: Level) -> tuple[LevelGraph, NavMesh] {
    meshes = [world->:HasNavMesh:->][?:NavMesh];
    if meshes {
        shipped = meshes[0].aas;
        atlas = graph_from_aas(shipped, level);
        return (atlas, build_navmesh(world, graph_aas(atlas, shipped), level.bsp));
    }
    atlas = read_level_graph(world, level, None, ReadOptions(sims=False));
    return (atlas, build_navmesh(world, graph_aas(atlas), level.bsp));
}
