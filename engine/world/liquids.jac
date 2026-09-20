"""Exact point-content queries for Q2/Q3 liquid brushes."""
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

edge HasLiquid {}
node LiquidSpace {}
node LiquidVolume {
    has kind: int,
        volume: CollisionMap;
}

walker SampleLiquid {
    has point: Vec3,
        result: int = 0;

    can begin with LiquidSpace entry {
        visit [here->:HasLiquid:->];
    }
    can sample with LiquidVolume entry {
        if here.volume.trace(self.point, self.point).start_solid {
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
    return space;
}
