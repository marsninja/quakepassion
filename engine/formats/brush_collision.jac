"""Q2/Q3 brush records adapted to shared expanded collision hulls."""
import from .bsp { Bsp }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

def add_model(collision: CollisionMap, bsp: Bsp, model: int, offset: Vec3) {
    width = 15.0 if bsp.game == "q3" else 16.0;
    mask = 65537 if bsp.game == "q3" else 65539;
    for index in bsp.models[model].brushes {
        brush = bsp.brushes[index];
        if brush.contents & mask == 0 or not brush.planes {
            continue;
        }
        normals: list[Vec3] = [];
        distances: list[float] = [];
        for plane in brush.planes {
            normals.append(bsp.planes[plane].normal);
            distances.append(bsp.planes[plane].distance);
        }
        collision.add_brush(
            normals,
            distances,
            Vec3(x=-width, y=-width, z=-24.0),
            Vec3(x=width, y=width, z=32.0),
            offset
        );
    }
}

def build_brush_collision(bsp: Bsp) -> CollisionMap {
    collision = CollisionMap(eye_height=26.0 if bsp.game == "q3" else 22.0);
    add_model(collision, bsp, 0, Vec3());
    for entity in bsp.entities {
        kind = entity.fields.get("classname", "");
        if kind
            not in [
                "func_wall",
                "func_door",
                "func_door_secret",
                "func_plat",
                "func_train",
                "func_button",
                "func_static",
                "func_bobbing",
                "func_rotating",
                "func_door_rotating"
            ] {
            continue;
        }
        model = entity.fields.get("model", "");
        if not model.startswith("*") {
            continue;
        }
        index = int(model[1:]);
        if index <= 0 or index >= len(bsp.models) {
            raise ValueError("Invalid collision model");
        }
        coords = entity.fields.get("origin", "0 0 0").split();
        if len(coords) != 3 {
            raise ValueError("Invalid collision origin");
        }
        add_model(
            collision,
            bsp,
            index,
            Vec3(x=float(coords[0]), y=float(coords[1]), z=float(coords[2]))
        );
    }
    collision.reindex();
    return collision;
}
