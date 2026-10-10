"""Q2 and Q3 area portals: the areas and portals of the map as a graph,
doors and relays opening them, the flood that numbers connected areas, and
what a shut portal seals off: sound, the world's faces and the models
beyond it."""
import from engine.world.area_portals {
    HasAreaPortal,
    OpensPortal,
    AreaPortalTick,
    chart_areas,
    load_area_portals,
    open_portals
}
import from engine.world.map_areas {
    AreaMap,
    MapArea,
    AreaPortal,
    HasAreaMap,
    Within,
    Joins,
    FloodAreaConnections,
    area_map_of
}
import from engine.world.level { Level, Split, BspArea, Front, Back, BspAreaProbe }
import from engine.world.models { ModelResource, attach_model, GatherModels }
import from engine.world.doors { Door, HasDoor }
import from engine.world.signals { Fire }
import from engine.world.world { World, Actor, move_to_area }
import from engine.formats.bsp { Bsp, MapEntity, AreaLink, Leaf, Model }
import from engine.formats.animated { AnimatedModel }
import from engine.math.aabb { AABB }
import from engine.math.vec3 { Vec3 }

"""Three areas in a row: 1 and 2 joined by portal 1, 2 and 3 by portal 2."""
def row_of_areas() -> Bsp {
    bsp = Bsp(game="q2");
    bsp.areas = [
        [],
        [AreaLink(portal=1, area=2)],
        [AreaLink(portal=1, area=1), AreaLink(portal=2, area=3)],
        [AreaLink(portal=2, area=2)]
    ];
    return bsp;
}

def test_door(entity: int) -> Door {
    return Door(
        model=1,
        trigger=AABB(mins=Vec3(), maxs=Vec3()),
        travel=Vec3(z=64.0),
        speed=100.0,
        hold_time=3.0,
        entity=entity
    );
}

test "FloodAreaConnections numbers the areas open portals join" {
    world = World();
    chart = AreaMap(first=1);
    for index in range(4) {
        chart.areas.append(MapArea(index=index));
    }
    world +>:HasAreaMap:+> chart;
    near = AreaPortal(style=1);
    far = AreaPortal(style=2);
    chart.areas[1] +>:Joins:+> near;
    chart.areas[2] +>:Joins:+> near;
    chart.areas[2] +>:Joins:+> far;
    chart.areas[3] +>:Joins:+> far;
    assert area_map_of(world) is chart;
    chart spawn FloodAreaConnections();
    # Every portal shut: three floods, and area 0 is not used.
    assert [area.floodnum for area in chart.areas] == [0, 1, 2, 3];
    assert chart.connected(2, 2) and not chart.connected(1, 2) and not chart.connected(1, 3);
    near.open = True;
    chart spawn FloodAreaConnections();
    assert chart.revision == 2;
    assert chart.connected(1, 2) and chart.connected(2, 1) and not chart.connected(1, 3);
    far.open = True;
    chart spawn FloodAreaConnections();
    assert chart.connected(1, 3) and [area.floodnum for area in chart.areas] == [0, 1, 1, 1];
    # Solid (area 0) is connected to nothing but itself.
    assert chart.connected(0, 0) and not chart.connected(0, 1) and not chart.connected(1, 9);
    assert not chart.connected(-1, -1);
    # CM_WriteAreaBits: the areas out of the view's flood are sealed.
    near.open = False;
    chart spawn FloodAreaConnections();
    chart.look(1, True);
    assert [area.sealed for area in chart.areas] == [True, False, True, True];
    chart.look(3, True);
    assert [area.sealed for area in chart.areas] == [True, True, False, False];
    # From outside every area, or with culling off, nothing is.
    chart.look(0, True);
    assert not [area for area in chart.areas if area.sealed];
    chart.look(3, False);
    assert not [area for area in chart.areas if area.sealed];
}

test "a door keeps its portal open while it is not shut and relays toggle theirs" {
    bsp = row_of_areas();
    bsp.entities = [
        MapEntity(fields={"classname": "func_door", "target": "gate", "model": "*1"}),
        MapEntity(fields={"classname": "func_areaportal", "targetname": "gate", "style": "1"}),
        MapEntity(fields={"classname": "func_areaportal", "targetname": "hatch", "style": "2"})
    ];
    world = World();
    door = test_door(0);
    world +>:HasDoor:+> door;
    charted = chart_areas(world, bsp, []);
    assert charted is not None;
    chart: AreaMap = charted;
    assert len(chart.areas) == 4;
    load_area_portals(world, bsp, chart);
    portals = [world->:HasAreaPortal:->][?:AreaPortal];
    assert len(portals) == 2;
    # CM_LoadMap floods once, with every portal shut.
    assert chart.revision == 1 and not chart.connected(1, 2);
    world spawn AreaPortalTick();
    assert open_portals(world) == set() and chart.revision == 1;
    door.state = "opening";
    world spawn AreaPortalTick();
    assert open_portals(world) == set([1]);
    assert chart.revision == 2 and chart.connected(1, 2) and not chart.connected(1, 3);
    # Nothing changed: no flood.
    world spawn AreaPortalTick();
    assert chart.revision == 2;
    door.state = "closed";
    world spawn AreaPortalTick();
    assert open_portals(world) == set() and not chart.connected(1, 2);
    # g_misc.c Use_Areaportal: each use toggles a portal no door holds.
    hatch = [portal for portal in portals if portal.style == 2][0];
    hatch.activation spawn Fire(emit=False);
    world spawn AreaPortalTick();
    assert open_portals(world) == set([2]) and chart.connected(2, 3) and not chart.connected(1, 3);
    hatch.activation spawn Fire(emit=False);
    world spawn AreaPortalTick();
    assert open_portals(world) == set() and not chart.connected(2, 3);
    # A map without areas has no chart, and its portals still follow doors.
    assert chart_areas(World(), Bsp(game="q2"), []) is None;
    assert chart_areas(World(), Bsp(game="q1"), []) is None;
}

"""A Q3 level of three leaves, every one in the others' PVS: leaf 0 (x > 0)
is area 0, leaves 1 and 2 (x < 0, split at y = 0) area 1. A door stands on
the plane between the areas."""
def two_area_level(world: World) -> Level {
    areas: list[BspArea] = [];
    leaves: list[Leaf] = [];
    for index in range(3) {
        area = BspArea(name=str(index), index=index, faces=[10 + index], bounds=AABB(mins=Vec3(), maxs=Vec3()));
        world ++> area;
        areas.append(area);
        leaves.append(
            Leaf(contents=0, vis_offset=-1, cluster=index, area=0 if index == 0 else 1, mins=Vec3(), maxs=Vec3())
        );
    }
    wall = Split(normal=Vec3(x=1.0), distance=0.0);
    inner = Split(normal=Vec3(y=1.0), distance=0.0);
    wall +>:Front:+> areas[0];
    wall +>:Back:+> inner;
    inner +>:Front:+> areas[1];
    inner +>:Back:+> areas[2];
    bsp = Bsp(
        game="q3",
        clusters=3,
        cluster_bytes=1,
        visibility=bytes([3, 0, 0, 0, 1, 0, 0, 0, 7, 7, 7]),
        leaves=leaves,
        models=[
            Model(head=0, first_face=0, face_count=3),
            Model(head=0, first_face=3, face_count=0, mins=Vec3(x=-8.0, y=16.0, z=0.0), maxs=Vec3(x=8.0, y=80.0, z=96.0))
        ],
        entities=[MapEntity(fields={"classname": "func_door", "model": "*1"})]
    );
    return Level(active=True, bsp=bsp, areas=areas, splits=[wall, inner]);
}

test "a Q3 door between two areas is their portal, and shut it culls what lies beyond" {
    world = World();
    level = two_area_level(world);
    door = test_door(0);
    world +>:HasDoor:+> door;
    charted = chart_areas(world, level.bsp, level.areas);
    assert charted is not None;
    chart: AreaMap = charted;
    assert chart.first == 0 and len(chart.areas) == 2;
    assert [zone.index for zone in [level.areas[2]->:Within:->][?:MapArea]] == [1];
    probe = BspAreaProbe(head=level.splits[0]);
    # SV_LinkEntity: the door's box reaches area 0 and, on the y > 0 side, area 1.
    assert [zone.index for zone in probe.touching(Vec3(x=-9.0, y=15.0), Vec3(x=9.0, y=81.0, z=97.0))] == [0, 1];
    assert [zone.index for zone in probe.touching(Vec3(x=4.0, y=-50.0), Vec3(x=9.0, y=50.0, z=8.0))] == [0];
    load_area_portals(world, level.bsp, chart, probe);
    level.area_map = chart;
    portals = [world->:HasAreaPortal:->][?:AreaPortal];
    assert len(portals) == 1 and len([portals[0]<-:Joins:<-]) == 2 and len([portals[0]<-:OpensPortal:<-]) == 1;
    # A monster in the far area.
    monster = Actor(pos=Vec3(x=-64.0, y=32.0));
    move_to_area(monster, level.areas[1]);
    attach_model(monster, ModelResource(name="far", model=AnimatedModel(), skins=[]));
    eye = Vec3(x=32.0);
    # Shut: R_MarkLeaves' areamask leaves only the eye's own area, and
    # nothing is sent from beyond the door.
    assert level.visible(world, eye, True) == [10];
    assert len((world spawn GatherModels()).draws) == 0;
    assert not chart.connected(0, 1);
    # From the far side the near area is the one sealed.
    assert level.visible(world, Vec3(x=-32.0, y=32.0), True) == [11, 12];
    assert len((world spawn GatherModels()).draws) == 1;
    # r_novis draws everything.
    assert level.visible(world, eye, False) == [10, 11, 12];
    assert len((world spawn GatherModels()).draws) == 1;
    # Use_BinaryMover: the portal opens as the door leaves its rest position.
    assert level.visible(world, eye, True) == [10];
    kept = level.visible(world, eye, True);
    door.state = "opening";
    world spawn AreaPortalTick();
    assert chart.connected(0, 1);
    opened = level.visible(world, eye, True);
    assert opened == [10, 11, 12] and opened is not kept;
    assert len((world spawn GatherModels()).draws) == 1;
    # The set is kept while neither the leaf nor the flood changes.
    assert level.visible(world, eye, True) is opened;
    # Reached_BinaryMover: shut again once it is back.
    door.state = "closed";
    world spawn AreaPortalTick();
    assert level.visible(world, eye, True) == [10];
    assert len((world spawn GatherModels()).draws) == 0;
}
