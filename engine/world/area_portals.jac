"""Area portals as the games open and close them.

Quake II (g_func.c door_use_areaportals, g_misc.c Use_Areaportal,
cmodel.c CM_SetAreaPortalState): a func_areaportal entity carries a portal
number of the map's table. A door opens the portals it targets while it
stands open, and a relay toggles one.

A level the studio bakes takes Quake II's: its bake numbers each
func_areaportal (`style`) and lists the two areas it stands between.

Quake III (g_mover.c Use_BinaryMover and Reached_BinaryMover, sv_game.c
SV_AdjustAreaPortalState): a door whose box reaches two areas is the portal
between them, open from the moment it leaves its rest position until it is
back.

The areas, the flood that numbers them and what it seals off are in
engine/world/map_areas.jac."""
import from engine.formats.numbers { atof, atoi }
import from .world { World, Area }
import from .doors { Door, HasDoor, DoorMember }
import from .signals { Signal, HasSignal }
import from .map_areas {
    AreaMap,
    MapArea,
    AreaPortal,
    AreaProbe,
    HasAreaMap,
    Within,
    Joins,
    FloodAreaConnections
}
import from ..formats.bsp { Bsp, model_bounds, mover_origin }
import from ..math.vec3 { Vec3 }

edge HasAreaPortal: World --> AreaPortal {}

"""A door and the portal it opens (door_use_areaportals,
SV_AdjustAreaPortalState); `start_open` doors (DOOR_START_OPEN) stand open
at rest."""
edge OpensPortal: Door --> AreaPortal {
    has start_open: bool = False;
}

"""CMod_LoadAreas and CMod_LoadLeafs' areas as a graph: a `MapArea` for
each area of the map, every leaf `Within` its own. None for a game or map
without areas. A studio's baked level numbers its areas as Quake II does,
from 1 (its solid leaves are in area 0)."""
def chart_areas(world: World, bsp: Bsp, leaves: list[Area]) -> AreaMap | None {
    if bsp.game not in ["q2", "q3", "passion"] {
        return None;
    }
    count = len(bsp.areas);
    for leaf in bsp.leaves {
        count = max(count, leaf.area + 1);
    }
    chart = AreaMap(first=0 if bsp.game == "q3" else 1);
    if count <= chart.first {
        return None;
    }
    for index in range(count) {
        chart.areas.append(MapArea(index=index));
    }
    world +>:HasAreaMap:+> chart;
    for index in range(min(len(leaves), len(bsp.leaves))) {
        area = chart.area(bsp.leaves[index].area);
        if area is not None {
            leaves[index] +>:Within:+> area;
        }
    }
    return chart;
}

"""The level's portals and the doors that hold them, then the first flood
(CM_LoadMap ends with FloodAreaConnections, every portal shut)."""
def load_area_portals(world: World, bsp: Bsp, chart: AreaMap | None = None, probe: AreaProbe | None = None) {
    if bsp.game in ["q2", "passion"] {
        load_entity_portals(world, bsp, chart);
    } elif bsp.game == "q3" and chart is not None and probe is not None {
        load_door_portals(world, bsp, chart, probe);
    }
    if chart is not None {
        chart spawn FloodAreaConnections();
    }
}

"""Q2 SP_func_areaportal: each entity is a portal that starts shut; the
areas listing its number (dareaportal_t) border it."""
def:priv load_entity_portals(world: World, bsp: Bsp, chart: AreaMap | None) {
    doors = [world->:HasDoor:->][?:Door];
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") != "func_areaportal" {
            continue;
        }
        activation = Signal(entities=[index]);
        world +>:HasSignal:+> activation;
        portal = AreaPortal(style=atoi(fields.get("style", "0")), activation=activation);
        world +>:HasAreaPortal:+> portal;
        if chart is not None {
            for area in range(min(len(bsp.areas), len(chart.areas))) {
                for link in bsp.areas[area] {
                    if link.portal == portal.style {
                        chart.areas[area] +>:Joins:+> portal;
                    }
                }
            }
        }
        name = fields.get("targetname", "");
        if not name {
            continue;
        }
        for door in doors {
            if door.entity < 0 or door.entity >= len(bsp.entities) {
                continue;
            }
            spawned = bsp.entities[door.entity].fields;
            if spawned.get("target", "") == name {
                flags = int(spawned.get("spawnflags", "0"));
                door +>:OpensPortal:start_open=flags & 1 != 0:+> portal;
            }
        }
    }
}

"""Q3 SV_LinkEntity and SV_AdjustAreaPortalState: a door part whose box
(its model's, a unit wider each way) reaches two areas is the portal
between them, held by its team's leader."""
def:priv load_door_portals(world: World, bsp: Bsp, chart: AreaMap, probe: AreaProbe) {
    margin = Vec3(x=1.0, y=1.0, z=1.0);
    for leader in [world->:HasDoor:->][?:Door] {
        parts = [leader];
        parts.extend([leader->:DoorMember:->][?:Door]);
        for part in parts {
            if part.entity < 0 or part.entity >= len(bsp.entities) or part.model <= 0 or part.model >= len(bsp.models) {
                continue;
            }
            fields = bsp.entities[part.entity].fields;
            box = model_bounds(bsp, part.model, mover_origin(fields));
            touched = probe.touching(box.mins.sub(margin), box.maxs.add(margin));
            if len(touched) < 2 {
                continue;
            }
            portal = AreaPortal();
            world +>:HasAreaPortal:+> portal;
            # areanum and areanum2: the first area met and the last other one.
            touched[0] +>:Joins:+> portal;
            touched[-1] +>:Joins:+> portal;
            leader +>:OpensPortal:start_open=atoi(fields.get("spawnflags", "0")) & 1 != 0:+> portal;
        }
    }
}

"""Once per tick: relays toggle their portals, and a door keeps the portals
it holds open whenever it is not at rest. A portal that changed floods the
areas again (CM_SetAreaPortalState, CM_AdjustAreaPortalState)."""
walker AreaPortalTick {
    has opened: list[int] = [],
        changed: bool = False;

    can begin with World entry {
        visit [here->:HasAreaPortal:->];
        visit [here->:HasAreaMap:->];
    }

    can settle with AreaPortal entry {
        was = here.open;
        if here.activation.pending % 2 == 1 {
            here.toggled = not here.toggled;
        }
        here.activation.pending = 0;
        links = [edge here<-:OpensPortal:<-];
        doors = [here<-:OpensPortal:<-][?:Door];
        if doors {
            here.open = False;
            for i in range(min(len(links), len(doors))) {
                shut_state = "open" if links[i].start_open else "closed";
                if doors[i].state != shut_state {
                    here.open = True;
                }
            }
        } else {
            here.open = here.toggled;
        }
        if here.open {
            self.opened.append(here.style);
        }
        if here.open != was {
            self.changed = True;
        }
    }

    can reflood with AreaMap entry {
        if self.changed {
            here spawn FloodAreaConnections();
        }
    }
}

"""The portal numbers open now."""
def open_portals(world: World) -> set[int] {
    return set([portal.style for portal in [world->:HasAreaPortal:->][?:AreaPortal] if portal.open]);
}
