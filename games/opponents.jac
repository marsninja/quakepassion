"""Small campaign roster and local arena training bots for the prototype."""
import math;
import from .arena_character { load_character }
import from engine.world.world { World, move_to_area }
import from engine.world.level { Level, spawn_player }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.signals { Signal, HasSignal }
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
        for entity_index in range(len(level.bsp.entities)) {
            entity = level.bsp.entities[entity_index];
            fields = entity.fields;
            kind = fields.get("classname", "");
            path = "";
            arena = level.bsp.game == "q3";
            if arena {
                if kind != "info_player_deathmatch" or count >= 3 {
                    continue;
                }
                path = "models/players/sarge";
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
                decision_wait=float(count % 12) / 120.0,
                support_wait=float(count % 6) / 120.0,
                yaw=float(fields.get("angle", "0")) * math.pi / 180.0
            );
            for signal in [world->:HasSignal:->][?:Signal] {
                if entity_index in signal.entities { enemy.activation = signal; }
            }
            if path {
                if path not in resources {
                    loaded = load_character(library) if arena else library.model(path);
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
                    frame_name = frames[i].name;
                    if frame_name.startswith("run") { enemy.animation.append(i); }
                    if frame_name.startswith("stand") { enemy.idle_animation.append(i); }
                    if frame_name.startswith("attack") or frame_name.startswith("attak") or frame_name.startswith("shoot") {
                        enemy.attack_animation.append(i);
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
