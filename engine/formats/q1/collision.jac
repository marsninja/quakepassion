"""Adapt BSP29's standing-player hull to the shared collision graph."""
import from ..bsp { Bsp }
import from ...physics.collision { CollisionMap, HullCell, HullFront, HullBack }
import from ...math.vec3 { Vec3 }
import from ...math.aabb { AABB }

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
                    "trigger_hurt",
                    "trigger_secret",
                    "trigger_once",
                    "trigger_multiple",
                    "trigger_changelevel",
                    "trigger_teleport",
                    "trigger_push",
                    "trigger_onlyregistered",
                    "trigger_setskill",
                    "trigger_monsterjump"
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
                    "func_button",
                    "func_episodegate",
                    "func_bossgate"
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
    if bsp.leaves {
        point_cells: list[HullCell] = [];
        point_leaves: list[HullCell] = [];
        for leaf in bsp.leaves {
            point_leaves.append(HullCell(contents=leaf.contents));
        }
        for branch in bsp.branches {
            plane = bsp.planes[branch.plane];
            point_cells.append(HullCell(normal=plane.normal, distance=plane.distance));
        }
        for i in range(len(point_cells)) {
            branch = bsp.branches[i];
            front = point_cells[branch.front]
                if branch.front >= 0
                else point_leaves[-branch.front - 1];
            back = point_cells[branch.back]
                if branch.back >= 0
                else point_leaves[-branch.back - 1];
            point_cells[i] +>:HullFront:+> front;
            point_cells[i] +>:HullBack:+> back;
        }
        for model in collision.models {
            head = bsp.models[model].head;
            collision.point_hulls.append(
                point_cells[head] if head >= 0 else point_leaves[-head - 1]
            );
        }
    }
    for i in range(len(collision.models)) {
        record = bsp.models[collision.models[i]];
        if collision.models[i] == 0
            or record.maxs.x <= record.mins.x
            or record.maxs.y <= record.mins.y
            or record.maxs.z <= record.mins.z {
            # World hull includes the solid exterior; synthetic unbounded hulls
            # must also keep their full narrow-phase semantics.
            collision.bounds.append(
                AABB(
                    mins=Vec3(x=-1.0e30, y=-1.0e30, z=-1.0e30),
                    maxs=Vec3(x=1.0e30, y=1.0e30, z=1.0e30)
                )
            );
        } else {
            # Q1's runtime expands on-disk submodel bounds by one unit
            # (Mod_LoadSubmodels). Without it the broad phase can discard a
            # contact inside the actual clip hull, letting riders sink into lifts.
            collision.bounds.append(
                AABB(
                    mins=record.mins.add(collision.offsets[i]).sub(
                        Vec3(x=17.0, y=17.0, z=33.0)
                    ),
                    maxs=record.maxs.add(collision.offsets[i]).add(
                        Vec3(x=17.0, y=17.0, z=25.0)
                    )
                )
            );
        }
    }
    collision.reindex();
    return collision;
}
