"""Small campaign roster and local arena training bots for the prototype."""
import math;
import from .enemies { enemy_rule }
import from engine.world.opponent_rule { OpponentRule }
import from .arena_character { load_character }
import from engine.world.world { World, move_to_area }
import from engine.world.level { Level, spawn_player }
import from engine.world.combat { Opponent, HasOpponent }
import from engine.world.speakers { Speaker, HasSpeaker }
import from engine.world.signals { Signal, HasSignal }
import from engine.world.models { ModelResource, HasModelResource, attach_model }
import from engine.assets.catalog { AssetCatalog }
import from engine.math.vec3 { Vec3 }

def populate_opponents(world: World, level: Level, directory: str) -> int {
    catalog = AssetCatalog(game=level.bsp.game, directory=directory);
    resources: dict[str, ModelResource] = {};
    count = 0;
    player_start = spawn_player(level).pos;
    try {
        for entity_index in range(len(level.bsp.entities)) {
            entity = level.bsp.entities[entity_index];
            fields = entity.fields;
            source = fields.get("asset_game", level.bsp.game);
            kind = fields.get("classname", "");
            path = "";
            arena = source == "q3";
            rule = OpponentRule(damage=6);
            if arena {
                if kind != "info_player_deathmatch"
                    or (level.bsp.game == "q3" and count >= 3) {
                    continue;
                }
                path = "models/players/sarge";
            } else {
                definition = enemy_rule(source, kind);
                if definition is None {
                    continue;
                }
                rule = definition;
                path = rule.model;
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
                dormant=rule.script == "chthon"
                    or (source == "q2" and int(fields.get("spawnflags", "0")) & 2 != 0),
                home=position,
                shot_random=1 + count * 7919,
                arena=level.bsp.game == "q3",
                rule=rule,
                walk_speed=rule.speed,
                health=rule.health,
                max_health=rule.health,
                decision_wait=float(count % 12) / 120.0,
                support_wait=float(count % 6) / 120.0,
                yaw=float(fields.get("angle", "0")) * math.pi / 180.0
            );
            if rule.attack_sound {
                speaker = Speaker(path=rule.attack_sound, origin=position);
                world +>:HasSpeaker:+> speaker;
                enemy.attack_speaker = speaker;
            }
            if rule.melee_sound {
                speaker = Speaker(path=rule.melee_sound, origin=position);
                world +>:HasSpeaker:+> speaker;
                enemy.melee_speaker = speaker;
            }
            for signal in [world->:HasSignal:->][?:Signal] {
                if entity_index in signal.entities {
                    enemy.activation = signal;
                }
            }
            if path {
                key = source + ":" + path + ":" + str(rule.skin);
                if key not in resources {
                    library = catalog.source(source);
                    loaded = load_character(library)
                        if arena
                        else library.model(path, skin=rule.skin);
                    resource = ModelResource(
                        name=key, model=loaded.model, skins=loaded.skins
                    );
                    resources[key] = resource;
                    world +>:HasModelResource:+> resource;
                }
                enemy.visual = attach_model(enemy, resources[key]);
                enemy.visual.offset = Vec3(z=-level.collision.eye_height);
                frames = resources[key].model.surfaces[0].frames;
                pain_family = "";
                death_family = "";
                pain_number = -1;
                death_number = -1;
                for i in range(len(frames)) {
                    frame_name = frames[i].name;
                    family = frame_name.rstrip("0123456789");
                    suffix = frame_name[len(family):];
                    number = int(suffix) if suffix else 0;
                    if frame_name.startswith("pain") {
                        if not pain_family {
                            pain_family = family;
                            pain_number = number - 1;
                        }
                        if family == pain_family and number == pain_number + 1 {
                            pain_number = number;
                            enemy.pain_animation.append(i);
                        }
                    }
                    if frame_name.startswith("death") {
                        if not death_family {
                            death_family = family;
                            death_number = number - 1;
                        }
                        if family == death_family and number == death_number + 1 {
                            death_number = number;
                            enemy.death_animation.append(i);
                        }
                    }
                    if frame_name.startswith("run") {
                        enemy.animation.append(i);
                    }
                    if frame_name.startswith("stand") {
                        enemy.idle_animation.append(i);
                    }
                    if frame_name.startswith("attack")
                        or frame_name.startswith("attak")
                        or frame_name.startswith("shoot") {
                        enemy.attack_animation.append(i);
                    }
                }
                if rule.pain_frames {
                    enemy.pain_animation = [];
                    for name in rule.pain_frames {
                        found = False;
                        for i in range(len(frames)) {
                            if frames[i].name == name {
                                enemy.pain_animation.append(i);
                                found = True;
                                break;
                            }
                        }
                        if not found {
                            raise ValueError(
                                "Missing pain frame: " + path + ":" + name
                            );
                        }
                    }
                }
                if rule.run_frames {
                    enemy.animation = [];
                    for name in rule.run_frames {
                        found = False;
                        for i in range(len(frames)) {
                            if frames[i].name == name {
                                enemy.animation.append(i);
                                found = True;
                                break;
                            }
                        }
                        if not found {
                            raise ValueError("Missing run frame: " + path + ":" + name);
                        }
                    }
                }
                if rule.attack_frames {
                    enemy.attack_animation = [];
                    for name in rule.attack_frames {
                        found = False;
                        for i in range(len(frames)) {
                            if frames[i].name == name {
                                enemy.attack_animation.append(i);
                                found = True;
                                break;
                            }
                        }
                        if not found {
                            raise ValueError(
                                "Missing attack frame: " + path + ":" + name
                            );
                        }
                    }
                }
                for name in rule.melee_frames {
                    found = False;
                    for i in range(len(frames)) {
                        if frames[i].name == name {
                            enemy.melee_animation.append(i);
                            found = True;
                            break;
                        }
                    }
                    if not found {
                        raise ValueError("Missing melee frame: " + path + ":" + name);
                    }
                }
                for name in rule.alternate_melee_frames {
                    found = False;
                    for i in range(len(frames)) {
                        if frames[i].name == name {
                            enemy.alternate_melee_animation.append(i);
                            found = True;
                            break;
                        }
                    }
                    if not found {
                        raise ValueError(
                            "Missing alternate melee frame: " + path + ":" + name
                        );
                    }
                }
                enemy.modeled = True;
            }
            enemy.visual.visible = not enemy.dormant;
            move_to_area(enemy, level.areas[level.locate(position)]);
            world +>:HasOpponent:+> enemy;
            count += 1;
        }
    } finally {
        catalog.close();
    }
    return count;
}
