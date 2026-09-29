"""Exact point-content queries for Q2/Q3 liquid brushes."""
import from ..formats.bsp { Bsp, brush_current_bits }
import from ..physics.collision { CollisionMap, Trace }
import from ..math.vec3 { Vec3 }

edge HasLiquid: LiquidSpace --> LiquidVolume {}
node LiquidSpace {}
"""The liquid brushes of one kind (and, in Q2, one current) in one model."""
node LiquidVolume {
    has kind: int,
        volume: CollisionMap,
        model: int = 0,
        offset: Vec3 = Vec3(),
        currents: int = 0;
}

"""Point contents over the liquid volumes: the thickest liquid at the point
and the current bits of every volume holding it (Q2 CM_PointContents ORs
the contents of each brush the point lies in)."""
walker SampleLiquid {
    has point: Vec3,
        result: int = 0,
        currents: int = 0;

    can begin with LiquidSpace entry {
        visit [here->:HasLiquid:->];
    }
    can sample with LiquidVolume entry {
        # A func_water volume carries its mover's current offset.
        local = self.point.sub(here.offset);
        if here.volume.trace(local, local).start_solid {
            self.result = max(self.result, here.kind);
            self.currents = self.currents | here.currents;
        }
    }
}

"""A box of `mins`..`maxs` swept from `start` to `finish` through the liquid
volumes, as CM_BoxTrace does with a CONTENTS_WATER|CONTENTS_SLIME|
CONTENTS_LAVA mask: `result` is the nearest entry into any liquid (starting
solid when the box starts in one)."""
walker TraceLiquid {
    has start: Vec3,
        finish: Vec3,
        mins: Vec3 = Vec3(),
        maxs: Vec3 = Vec3(),
        result: Trace = Trace();

    can begin with LiquidSpace entry {
        self.result = Trace(end=self.finish);
        visit [here->:HasLiquid:->];
    }

    can sweep with LiquidVolume entry {
        # The volumes are brushes for a point; the box moves their planes.
        body = here.volume.for_body(0.0, 0.0, self.mins, self.maxs);
        hit = body.trace(self.start.sub(here.offset), self.finish.sub(here.offset));
        if hit.start_solid {
            self.result.start_solid = True;
        }
        if hit.fraction < self.result.fraction {
            self.result.fraction = hit.fraction;
            self.result.normal = hit.normal;
            self.result.end = self.start.lerp(self.finish, hit.fraction);
        }
    }
}

"""What one point lies in: its liquid kind and Q2 current bits."""
obj LiquidSample {
    has kind: int = 0,
        currents: int = 0;
}

"""How deep a body stands in liquid (Q1 SV_CheckWater, Q2
PM_CatagorizePosition, Q3 PM_SetWaterLevel waterlevel), the worst liquid
it touches, and the current pushing at its feet (Q2 pm->watertype's
CONTENTS_CURRENT_* as a direction, zero without one)."""
obj Immersion {
    has depth: int = 0,
        kind: int = 0,
        current: Vec3 = Vec3();
}

# Canonical contents: 0 dry, 1 water, 2 slime, 3 lava. Q1 SV_PointContents
# counts the CONTENTS_CURRENT_* leaves (-9 to -14) as water.
def liquid_kind(contents: int, game: str) -> int {
    if game == "q1" {
        if contents <= -9 and contents >= -14 {
            return 1;
        }
        return -contents - 2 if contents >= -5 and contents <= -3 else 0;
    }
    if contents & 8 {
        return 3;
    }
    if contents & 16 {
        return 2;
    }
    return 1 if contents & 32 else 0;
}

"""Link one volume per liquid kind and current among `model`'s brushes."""
def add_liquid_volumes(space: LiquidSpace, bsp: Bsp, model: int) {
    groups: dict[int, CollisionMap] = {};
    order: list[int] = [];
    for index in bsp.models[model].brushes {
        brush = bsp.brushes[index];
        kind = liquid_kind(brush.contents, bsp.game);
        if kind == 0 or not brush.planes {
            continue;
        }
        key = kind | brush_current_bits(brush.contents, bsp.game);
        if key not in groups {
            # Brushes as they are, for points (and boxes by TraceLiquid).
            groups[key] = CollisionMap(hull_mins=Vec3(), hull_maxs=Vec3());
            order.append(key);
        }
        normals: list[Vec3] = [];
        distances: list[float] = [];
        for plane in brush.planes {
            normals.append(bsp.planes[plane].normal);
            distances.append(bsp.planes[plane].distance);
        }
        groups[key].add_brush(normals, distances, Vec3(), Vec3(), Vec3());
    }
    for key in order {
        volume = groups[key];
        volume.reindex();
        space +>:HasLiquid:+> LiquidVolume(
            kind=key & 3, volume=volume, model=model, currents=key & 0xFC0000
        );
    }
}

def load_liquids(bsp: Bsp) -> LiquidSpace {
    space = LiquidSpace();
    if bsp.game == "q1" or not bsp.models {
        return space;
    }
    add_liquid_volumes(space, bsp, 0);
    # Q2 func_water: a door-like mover whose brushes are liquid.
    for entity in bsp.entities {
        reference = entity.fields.get("model", "");
        if bsp.game != "q2" or entity.fields.get("classname", "") != "func_water" or not reference.startswith("*") {
            continue;
        }
        model = int(reference[1:]);
        if model <= 0 or model >= len(bsp.models) {
            continue;
        }
        add_liquid_volumes(space, bsp, model);
    }
    return space;
}
