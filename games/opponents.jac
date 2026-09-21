"""Small campaign roster and local arena training bots for the prototype."""
import math;
import from engine.world.world { World, move_to_area }
import from engine.world.level { Level, spawn_player }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.models { ModelResource, HasModelResource, attach_model }
import from engine.assets.library { AssetLibrary }
import from engine.math.vec3 { Vec3 }

def populate_opponents(world: World, level: Level, directory: str) -> int {
    library = AssetLibrary(game=level.bsp.game);
    resources: dict[str, ModelResource] = {};
    count = 0;
    player_start = spawn_player(level).pos;
    library.open(directory);
    try {
        for entity in level.bsp.entities {
            fields = entity.fields;
            kind = fields.get("classname", "");
            path = "";
            arena = level.bsp.game == "q3";
            if arena {
                if kind != "info_player_deathmatch" or count >= 3 {
                    continue;
                }
            } elif level.bsp.game == "q1" {
                if kind not in ["monster_army"] {
                    continue;
                }
                if int(fields.get("spawnflags", "0")) & 512 {
                    continue;
                }
                path = "progs/soldier.mdl";
            } else {
                if kind
                    not in [
                        "monster_soldier",
                        "monster_soldier_light",
                        "monster_soldier_ss",
                        "monster_infantry"
                    ] {
                    continue;
                }
                if int(fields.get("spawnflags", "0")) & 512 {
                    continue;
                }
                path = "models/monsters/infantry/tris.md2"
                    if kind == "monster_infantry"
                    else "models/monsters/soldier/tris.md2";
            }
            if fields.get("targetname", "") {
                continue;
            }
            parts = fields.get("origin", "0 0 0").split();
            if len(parts) != 3 {
                raise ValueError("Invalid opponent origin");
            }
            origin = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            # Opponent movement uses the same eye/body contract as the player.
            position = origin.add(Vec3(z=level.collision.eye_height));
            if arena and position.sub(player_start).length() < 80.0 {
                continue;
            }
            enemy = Opponent(
                pos=position,
                home=position,
                arena=arena,
                walk_speed=100.0,
                health=60,
                max_health=60,
                yaw=float(fields.get("angle", "0")) * math.pi / 180.0
            );
            if path {
                if path not in resources {
                    loaded = library.model(path);
                    resource = ModelResource(
                        name=path, model=loaded.model, skins=loaded.skins
                    );
                    resources[path] = resource;
                    world +>:HasModelResource:+> resource;
                }
                enemy.visual = attach_model(enemy, resources[path]);
                enemy.visual.offset = Vec3(z=-level.collision.eye_height);
                frames = resources[path].model.surfaces[0].frames;
                for i in range(len(frames)) {
                    if frames[i].name.startswith("run") {
                        enemy.animation.append(i);
                    }
                }
                enemy.modeled = True;
            }
            move_to_area(enemy, level.areas[level.locate(position)]);
            world +>:HasOpponent:+> enemy;
            count += 1;
        }
    } finally {
        library.close();
    }
    return count;
}
