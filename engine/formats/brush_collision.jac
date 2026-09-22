"""Q2/Q3 brush records adapted to shared expanded collision hulls."""
import from .bsp { Bsp }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

def add_model(
    collision: CollisionMap, bsp: Bsp, model: int, offset: Vec3, volume: bool = False
) {
    first = len(collision.hulls);
    width = 15.0 if bsp.game == "q3" else 16.0;
    mask = 65537 if bsp.game == "q3" else 65539;
    for index in bsp.models[model].brushes {
        brush = bsp.brushes[index];
        if (not volume and brush.contents & mask == 0) or not brush.planes {
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
        collision.hulls[-1].point_blocking = brush.contents
            & (1 if bsp.game == "q3" else 3)
            != 0;
    }
    if bsp.game == "q3" and not volume {
        record = bsp.models[model];
        for index in range(record.first_face, record.first_face + record.face_count) {
            face = bsp.faces[index];
            if not face.patch {
                continue;
            }
            material = bsp.textures[face.texture];
            if material.contents & mask == 0 {
                continue;
            }
            first_patch = len(collision.hulls);
            for i in range(0, len(face.indices), 3) {
                collision.add_triangle(
                    face.vertices[face.indices[i]],
                    face.vertices[face.indices[i + 1]],
                    face.vertices[face.indices[i + 2]],
                    Vec3(x=-width, y=-width, z=-24.0),
                    Vec3(x=width, y=width, z=32.0),
                    offset
                );
            }
            for i in range(first_patch, len(collision.hulls)) {
                collision.hulls[i].point_blocking = material.contents & 1 != 0;
            }
        }
    }
    for i in range(first, len(collision.hulls)) {
        collision.models.append(model);
    }
}

def build_brush_collision(bsp: Bsp, triggers: bool = False) -> CollisionMap {
    collision = CollisionMap(eye_height=26.0 if bsp.game == "q3" else 22.0);
    if not triggers {
        add_model(collision, bsp, 0, Vec3());
    }
    for entity in bsp.entities {
        kind = entity.fields.get("classname", "");
        if not triggers
            and bsp.game == "q2"
            and kind in ["misc_teleporter", "misc_teleporter_dest"] {
            if kind == "misc_teleporter" and not entity.fields.get("target", "") {
                continue;
            }
            coords = entity.fields.get("origin", "0 0 0").split();
            if len(coords) != 3 {
                raise ValueError("Invalid teleport pad origin");
            }
            collision.add_box(
                Vec3(x=-32.0, y=-32.0, z=-24.0),
                Vec3(x=32.0, y=32.0, z=-16.0),
                Vec3(x=float(coords[0]), y=float(coords[1]), z=float(coords[2])),
                Vec3(x=-16.0, y=-16.0, z=-24.0),
                Vec3(x=16.0, y=16.0, z=32.0)
            );
            collision.models.append(-1);
            continue;
        }

        if triggers
            and kind
                not in [
                    "trigger_hurt",
                    "trigger_once",
                    "trigger_multiple",
                    "trigger_teleport",
                    "trigger_push"
                ] {
            continue;
        }
        if not triggers
            and kind
                not in [
                    "func_wall",
                    "func_explosive",
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
            Vec3(x=float(coords[0]), y=float(coords[1]), z=float(coords[2])),
            volume=triggers
        );
    }
    collision.reindex();
    return collision;
}
