"""Adapt BSP29's standing-player hull to the shared collision graph."""
import from ..bsp { Bsp }
import from ...physics.collision { CollisionMap, HullCell, HullFront, HullBack }
import from ...math.vec3 { Vec3 }

def build_collision(bsp: Bsp, triggers: bool = False) -> CollisionMap {
    cells: list[HullCell] = [];
    terminals: list[HullCell] = [];
    for contents in range(1, 7) {
        terminals.append(HullCell(contents=-contents));
    }
    for clip in bsp.clipnodes {
        plane = bsp.planes[clip.plane];
        cells.append(HullCell(normal=plane.normal, distance=plane.distance));
    }
    for i in range(len(cells)) {
        clip = bsp.clipnodes[i];
        front = cells[clip.front] if clip.front >= 0 else terminals[-clip.front - 1];
        back = cells[clip.back] if clip.back >= 0 else terminals[-clip.back - 1];
        cells[i] +>:HullFront:+> front;
        cells[i] +>:HullBack:+> back;
    }
    collision = CollisionMap();
    if not triggers {
        head = bsp.models[0].player_hull;
        collision.hulls.append(cells[head] if head >= 0 else terminals[-head - 1]);
        collision.offsets.append(Vec3());
        collision.models.append(0);
    }
    # Start solid brush entities at their authored position; shared movers update
    # their offsets. Triggers and illusionary brushes are not solid.
    for entity in bsp.entities {
        kind = entity.fields.get("classname", "");
        if triggers
            and kind
                not in [
                    "trigger_once",
                    "trigger_multiple",
                    "trigger_changelevel",
                    "trigger_teleport",
                    "trigger_push"
                ] {
            continue;
        }
        if not triggers
            and kind
                not in [
                    "func_wall",
                    "func_door",
                    "func_door_secret",
                    "func_plat",
                    "func_train",
                    "func_button"
                ] {
            continue;
        }
        model = entity.fields.get("model", "");
        if not model.startswith("*") {
            continue;
        }
        index = int(model[1:]);
        if index <= 0 or index >= len(bsp.models) {
            raise ValueError("Invalid collision brush model");
        }
        coords = entity.fields.get("origin", "0 0 0").split();
        if len(coords) != 3 {
            raise ValueError("Invalid collision brush origin");
        }
        collision.models.append(index);
        head = bsp.models[index].player_hull;
        collision.hulls.append(cells[head] if head >= 0 else terminals[-head - 1]);
        collision.offsets.append(
            Vec3(x=float(coords[0]), y=float(coords[1]), z=float(coords[2]))
        );
    }
    return collision;
}
