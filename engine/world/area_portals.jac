"""Q2 areas and their area portals (cmodel.c CM_SetAreaPortalState,
CM_AreasConnected). The map is cut into areas joined through portals that
func_areaportal entities open and close; a door opens the portals it targets
while it stands open (g_func.c door_use_areaportals) and a relay toggles one
(g_misc.c Use_Areaportal). Sound crosses only between connected areas."""
import from .world { World }
import from .doors { Door, HasDoor }
import from .signals { Signal, HasSignal }
import from ..formats.bsp { Bsp }

edge HasAreaPortal: World --> AreaPortal {}
"""One func_areaportal: `style` is its portal number in the map's portal
table. `toggled` is Use_Areaportal's count; doors that target the portal
decide its state instead while any does."""
node AreaPortal {
    has style: int,
        toggled: bool = False,
        open: bool = False,
        activation: Signal = Signal();
}

"""A door and the portal it opens (door_use_areaportals); `start_open` doors
(DOOR_START_OPEN) stand open at rest."""
edge OpensPortal: Door --> AreaPortal {
    has start_open: bool = False;
}

def load_area_portals(world: World, bsp: Bsp) {
    if bsp.game != "q2" {
        return;
    }
    doors = [world->:HasDoor:->][?:Door];
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") != "func_areaportal" {
            continue;
        }
        activation = Signal(entities=[index]);
        world +>:HasSignal:+> activation;
        portal = AreaPortal(style=int(fields.get("style", "0")), activation=activation);
        world +>:HasAreaPortal:+> portal;
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

"""Once per tick: relays toggle their portals, and a door keeps the portals it
targets open whenever it is not shut."""
walker AreaPortalTick {
    has opened: list[int] = [];

    can begin with World entry {
        visit [here->:HasAreaPortal:->];
    }

    can settle with AreaPortal entry {
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
    }
}

"""The portal numbers open now."""
def open_portals(world: World) -> set[int] {
    return set([portal.style for portal in [world->:HasAreaPortal:->][?:AreaPortal] if portal.open]);
}

"""CM_AreasConnected: whether sound can pass from area `first` to area
`second` through open portals. Maps without areas connect everything."""
def areas_connected(bsp: Bsp, first: int, second: int, opened: set[int]) -> bool {
    if first == second or not bsp.areas {
        return True;
    }
    if first < 0 or second < 0 or first >= len(bsp.areas) or second >= len(bsp.areas) {
        return False;
    }
    reached: set[int] = set([first]);
    frontier = [first];
    while frontier {
        area = frontier.pop();
        for link in bsp.areas[area] {
            if link.portal in opened and link.area not in reached {
                if link.area == second {
                    return True;
                }
                reached.add(link.area);
                frontier.append(link.area);
            }
        }
    }
    return False;
}
