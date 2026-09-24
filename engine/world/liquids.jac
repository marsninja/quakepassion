"""Exact point-content queries for Q2/Q3 liquid brushes."""
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

edge HasLiquid: LiquidSpace --> LiquidVolume {}
node LiquidSpace {}
node LiquidVolume {
    has kind: int,
        volume: CollisionMap,
        model: int = 0,
        offset: Vec3 = Vec3();
}

walker SampleLiquid {
    has point: Vec3,
        result: int = 0;

    can begin with LiquidSpace entry {
        visit [here->:HasLiquid:->];
    }
    can sample with LiquidVolume entry {
        # A func_water volume carries its mover's current offset.
        local = self.point.sub(here.offset);
        if here.volume.trace(local, local).start_solid {
            self.result = max(self.result, here.kind);
        }
    }
}

obj Immersion {
    has depth: int = 0,
        kind: int = 0;
}

# Canonical contents: 0 dry, 1 water, 2 slime, 3 lava.
def liquid_kind(contents: int, game: str) -> int {
    if game == "q1" {
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

def load_liquids(bsp: Bsp) -> LiquidSpace {
    space = LiquidSpace();
    if bsp.game == "q1" or not bsp.models {
        return space;
    }
    for kind in [1, 2, 3] {
        volume = CollisionMap();
        for index in bsp.models[0].brushes {
            brush = bsp.brushes[index];
            if liquid_kind(brush.contents, bsp.game) != kind or not brush.planes {
                continue;
            }
            normals: list[Vec3] = [];
            distances: list[float] = [];
            for index in brush.planes {
                normals.append(bsp.planes[index].normal);
                distances.append(bsp.planes[index].distance);
            }
            volume.add_brush(normals, distances, Vec3(), Vec3(), Vec3());
        }
        if volume.hulls {
            volume.reindex();
            space +>:HasLiquid:+> LiquidVolume(kind=kind, volume=volume);
        }
    }
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
        for kind in [1, 2, 3] {
            volume = CollisionMap();
            for index in bsp.models[model].brushes {
                brush = bsp.brushes[index];
                if liquid_kind(brush.contents, bsp.game) != kind or not brush.planes {
                    continue;
                }
                normals: list[Vec3] = [];
                distances: list[float] = [];
                for plane in brush.planes {
                    normals.append(bsp.planes[plane].normal);
                    distances.append(bsp.planes[plane].distance);
                }
                volume.add_brush(normals, distances, Vec3(), Vec3(), Vec3());
            }
            if volume.hulls {
                volume.reindex();
                space +>:HasLiquid:+> LiquidVolume(kind=kind, volume=volume, model=model);
            }
        }
    }
    return space;
}
