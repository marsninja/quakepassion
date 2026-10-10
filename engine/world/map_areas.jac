"""The areas a Quake II or Quake III map is cut into, and what closed area
portals seal off (Q2 cmodel.c, Q3 cm_test.c: FloodAreaConnections,
FloodArea_r, CM_AreasConnected, CM_WriteAreaBits).

Every leaf of the map lies `Within` one `MapArea` (dleaf_t area; the `Area`
nodes of the level graph are the leaves themselves). Areas meet only at area
portals: an area `Joins` each `AreaPortal` on its border, and the portal's
`open` flag says whether the two sides are connected now. Doors and relays
open and close the portals (engine/world/area_portals.jac).

Whenever a portal changes, `FloodAreaConnections` numbers the areas again:
areas that reach each other through open portals share a flood number.
Sound, sight for the renderer and the entities sent to the view all ask the
same thing of it: whether two areas carry the same number."""
import from .world { World, Area }
import from .signals { Signal }
import from ..math.vec3 { Vec3 }

"""The level's areas, in index order, and the view's side of them.
`first` is the lowest area the map uses: Q2 leaves area 0 unused (solid
leaves carry it), Q3 numbers from 0 and marks solid leaves -1."""
node AreaMap {
    has first: int = 1,
        areas: list[MapArea] = [],
        # floodvalid, and a count of the floods run (what was built from
        # one is stale once it moves on).
        floodvalid: int = 0,
        revision: int = 0,
        # The flood number of the area the frame is drawn from
        # (CM_WriteAreaBits' area), -1 while nothing is sealed off.
        view_flood: int = -1;

    """The area of this index, or None for a leaf outside every area."""
    def area(index: int) -> MapArea | None {
        if index < self.first or index >= len(self.areas) {
            return None;
        }
        return self.areas[index];
    }

    """CM_AreasConnected: whether open portals join two areas. Q2's unused
    area 0 (solid) is connected to itself alone, Q3's -1 to nothing."""
    def connected(first: int, second: int) -> bool {
        if first == second {
            return first >= 0;
        }
        one = self.area(first);
        other = self.area(second);
        return one is not None and other is not None and one.floodnum == other.floodnum;
    }

    """CM_WriteAreaBits for a frame drawn from area `index`: every area out
    of its flood is `sealed`. With `culling` off (r_novis), or from outside
    every area, nothing is."""
    def look(index: int, culling: bool) {
        seen = self.area(index) if culling else None;
        flood = seen.floodnum if seen is not None else -1;
        if flood == self.view_flood {
            return;
        }
        self.view_flood = flood;
        for area in self.areas {
            area.sealed = flood >= 0 and area.floodnum != flood;
        }
    }
}

edge HasAreaMap: World --> AreaMap {}

"""One area (carea_t): its flood number, valid while `floodvalid` is the
map's, and whether closed portals hide it from the current view."""
node MapArea {
    has index: int,
        floodnum: int = 0,
        floodvalid: int = 0,
        sealed: bool = False;
}

"""A leaf lies within its area (dleaf_t area)."""
edge Within: Area --> MapArea {}

"""One area portal. In Q2 it is a func_areaportal entity, `style` being its
number in the map's portal table (dareaportal_t portalnum), and `toggled`
Use_Areaportal's count; a portal number no entity carries stays shut. In
Q3 it is a door standing between two areas (SV_AdjustAreaPortalState).
`activation` takes a relay's use."""
node AreaPortal {
    has style: int = 0,
        toggled: bool = False,
        open: bool = False,
        activation: Signal = Signal();
}

"""An area borders a portal (dareaportal_t: the far side `Joins` it too)."""
edge Joins: MapArea --> AreaPortal {}

"""FloodArea_r: carry a flood number from an area through every open
portal on its border to the areas beyond."""
walker FloodArea {
    has floodnum: int,
        floodvalid: int;

    can flood with MapArea entry {
        if here.floodvalid == self.floodvalid {
            return;
        }
        here.floodnum = self.floodnum;
        here.floodvalid = self.floodvalid;
        visit [here->:Joins:->];
    }

    can cross with AreaPortal entry {
        if here.open {
            visit [here<-:Joins:<-];
        }
    }
}

"""FloodAreaConnections: every flood so far is void; each area not yet
reached starts a new one."""
walker FloodAreaConnections {
    has floodnum: int = 0;

    can renumber with AreaMap entry {
        here.floodvalid += 1;
        here.revision += 1;
        for area in here.areas[here.first:] {
            if area.floodvalid != here.floodvalid {
                self.floodnum += 1;
                area spawn FloodArea(floodnum=self.floodnum, floodvalid=here.floodvalid);
            }
        }
        # The view is drawn from a flood number that no longer means anything.
        here.view_flood = -1;
        for area in here.areas {
            area.sealed = False;
        }
    }
}

"""SV_LinkEntity's areas for a box: the areas of the leaves it reaches, in
the order met. The level supplies CM_BoxLeafnums through its BSP graph
(`touching`, abstract so it dispatches to the level module's
implementation)."""
obj AreaProbe {
    def touching(mins: Vec3, maxs: Vec3) -> list[MapArea] abst;
}

"""The level's area map (None for a level without areas)."""
def area_map_of(world: World) -> AreaMap | None {
    maps = [world->:HasAreaMap:->][?:AreaMap];
    return maps[0] if maps else None;
}
