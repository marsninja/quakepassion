"""Q2 area portals: the areas and portals parsed from the map, doors and
relays opening them, and sound crossing only between connected areas."""
import from engine.world.area_portals {
    AreaPortal,
    HasAreaPortal,
    AreaPortalTick,
    load_area_portals,
    open_portals,
    areas_connected
}
import from engine.world.doors { Door, HasDoor }
import from engine.world.signals { Fire }
import from engine.world.world { World }
import from engine.formats.bsp { Bsp, MapEntity, AreaLink }
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

test "areas connect only through open portals" {
    bsp = row_of_areas();
    assert areas_connected(bsp, 2, 2, set());
    assert not areas_connected(bsp, 1, 3, set());
    assert not areas_connected(bsp, 1, 3, set([1]));
    assert areas_connected(bsp, 1, 3, set([1, 2]));
    assert areas_connected(bsp, 3, 2, set([2]));
    # A map without areas connects everything.
    assert areas_connected(Bsp(game="q2"), 1, 5, set());
}

test "a door keeps its portal open while it is not shut and relays toggle theirs" {
    bsp = row_of_areas();
    bsp.entities = [
        MapEntity(fields={"classname": "func_door", "target": "gate", "model": "*1"}),
        MapEntity(fields={"classname": "func_areaportal", "targetname": "gate", "style": "1"}),
        MapEntity(fields={"classname": "func_areaportal", "targetname": "hatch", "style": "2"})
    ];
    world = World();
    door = Door(
        model=1,
        trigger=AABB(mins=Vec3(), maxs=Vec3()),
        travel=Vec3(z=64.0),
        speed=100.0,
        hold_time=3.0,
        entity=0
    );
    world +>:HasDoor:+> door;
    load_area_portals(world, bsp);
    portals = [world->:HasAreaPortal:->][?:AreaPortal];
    assert len(portals) == 2;
    world spawn AreaPortalTick();
    assert open_portals(world) == set();
    door.state = "opening";
    world spawn AreaPortalTick();
    assert open_portals(world) == set([1]);
    assert areas_connected(bsp, 1, 2, open_portals(world));
    assert not areas_connected(bsp, 1, 3, open_portals(world));
    door.state = "closed";
    world spawn AreaPortalTick();
    assert open_portals(world) == set();
    # g_misc.c Use_Areaportal: each use toggles a portal no door holds.
    hatch = [portal for portal in portals if portal.style == 2][0];
    hatch.activation spawn Fire(emit=False);
    world spawn AreaPortalTick();
    assert open_portals(world) == set([2]);
    hatch.activation spawn Fire(emit=False);
    world spawn AreaPortalTick();
    assert open_portals(world) == set();
}
