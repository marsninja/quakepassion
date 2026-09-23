"""Campaign rosters and local arena training bots populated from map entities."""
import math;
import from .enemies { enemy_rule }
import from engine.world.opponent_rule { OpponentRule }
import from .arena_character { load_character }
import from engine.world.world { World, move_to_area }
import from engine.world.level { Level, spawn_player }
import from engine.world.combat { Opponent, HasOpponent, ensure_profiles }
import from engine.world.finale { TeleportTrain, HasTeleportTrain }
import from engine.world.speakers { Speaker, HasSpeaker }
import from engine.world.signals { Signal, HasSignal }
import from engine.world.models { ModelResource, HasModelResource, attach_model }
import from engine.formats.animated { AnimationFrame }
import from engine.assets.catalog { AssetCatalog }
import from engine.math.vec3 { Vec3 }

def frame_indices(
    frames: list[AnimationFrame], names: list[str], path: str, label: str
) -> list[int] {
    result: list[int] = [];
    for name in names {
        found = -1;
        for i in range(len(frames)) {
            if frames[i].name == name {
                found = i;
                break;
            }
        }
        if found < 0 {
            raise ValueError("Missing " + label + " frame: " + path + ":" + name);
        }
        result.append(found);
    }
    return result;
}

# One positional speaker per distinct sound file an opponent can request.
def register_speaker(world: World, enemy: Opponent, path: str) -> Speaker | None {
    if not path {
        return None;
    }
    for i in range(len(enemy.speaker_paths)) {
        if enemy.speaker_paths[i] == path {
            return enemy.speakers[i];
        }
    }
    speaker = Speaker(path=path, origin=enemy.pos.add(Vec3()));
    world +>:HasSpeaker:+> speaker;
    enemy.speakers.append(speaker);
    enemy.speaker_paths.append(path);
    return speaker;
}

# The teleport train is a point entity with the original spiked ball model.
def populate_finale(world: World, level: Level, directory: str) -> int {
    trains = [world->:HasTeleportTrain:->][?:TeleportTrain];
    if not trains {
        return 0;
    }
    catalog = AssetCatalog(game=level.bsp.game, directory=directory);
    try {
        loaded = catalog.model("q1:progs/teleport.mdl");
        resource = ModelResource(
            name="q1:progs/teleport.mdl", model=loaded.model, skins=loaded.skins
        );
        world +>:HasModelResource:+> resource;
        for train in trains {
            train.visual = attach_model(train, resource);
            move_to_area(train, level.areas[level.locate(train.pos)]);
        }
    } finally {
        catalog.close();
    }
    return len(trains);
}

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
            flags = int(fields.get("spawnflags", "0"));
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
                definition = enemy_rule(source, kind, flags);
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
                eye_height=level.collision.eye_height,
                dormant=rule.script == "chthon"
                    or (
                        source == "q2"
                        and flags & 2 != 0
                        and not rule.decoration
                    ),
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
            ensure_profiles(enemy);
            if rule.attack_sound {
                enemy.attack_speaker = register_speaker(world, enemy, rule.attack_sound);
            }
            if rule.melee_sound {
                enemy.melee_speaker = register_speaker(world, enemy, rule.melee_sound);
            }
            for profile in enemy.profiles {
                register_speaker(world, enemy, profile.sound);
                register_speaker(world, enemy, profile.extra_sound);
            }
            register_speaker(world, enemy, rule.sight_sound);
            for pain_sound in rule.pain_sounds {
                register_speaker(world, enemy, pain_sound);
            }
            register_speaker(world, enemy, rule.death_sound);
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
                    enemy.pain_animation = frame_indices(
                        frames, rule.pain_frames, path, "pain"
                    );
                }
                for variant in rule.pain_variants {
                    enemy.pain_animations.append(
                        frame_indices(frames, variant, path, "pain")
                    );
                }
                if rule.knockdown_frames {
                    enemy.knockdown_animation = frame_indices(
                        frames, rule.knockdown_frames, path, "knockdown"
                    );
                }
                if rule.run_frames {
                    enemy.animation = frame_indices(frames, rule.run_frames, path, "run");
                }
                if rule.idle_frames {
                    enemy.idle_animation = frame_indices(
                        frames, rule.idle_frames, path, "idle"
                    );
                }
                if rule.death_frames {
                    enemy.death_animation = frame_indices(
                        frames, rule.death_frames, path, "death"
                    );
                }
                if rule.attack_frames {
                    enemy.attack_animation = frame_indices(
                        frames, rule.attack_frames, path, "attack"
                    );
                }
                enemy.melee_animation = frame_indices(
                    frames, rule.melee_frames, path, "melee"
                );
                enemy.alternate_melee_animation = frame_indices(
                    frames, rule.alternate_melee_frames, path, "alternate melee"
                );
                for profile in enemy.profiles {
                    enemy.profile_animations.append(
                        frame_indices(frames, profile.frames, path, profile.name)
                    );
                }
                if not enemy.animation {
                    enemy.animation = enemy.idle_animation;
                }
                enemy.modeled = True;
            }
            enemy.visual.visible = not enemy.dormant;
            move_to_area(enemy, level.areas[level.locate(position)]);
            world +>:HasOpponent:+> enemy;
            count += 1;
            if rule.successor {
                follower = enemy_rule(source, rule.successor, 0);
                if follower is None {
                    raise ValueError("Unknown successor: " + rule.successor);
                }
                heir = Opponent(
                    pos=position,
                    eye_height=level.collision.eye_height,
                    dormant=True,
                    home=position,
                    shot_random=1 + count * 7919,
                    rule=follower,
                    walk_speed=follower.speed,
                    health=follower.health,
                    max_health=follower.health,
                    yaw=enemy.yaw
                );
                ensure_profiles(heir);
                for profile in heir.profiles {
                    register_speaker(world, heir, profile.sound);
                    register_speaker(world, heir, profile.extra_sound);
                }
                register_speaker(world, heir, follower.sight_sound);
                for pain_sound in follower.pain_sounds {
                    register_speaker(world, heir, pain_sound);
                }
                register_speaker(world, heir, follower.death_sound);
                # The map's targets belong to the last form of the boss.
                heir.activation = enemy.activation;
                enemy.activation = Signal();
                enemy.successor = heir;
                heir_key = source + ":" + follower.model + ":" + str(follower.skin);
                if heir_key not in resources {
                    heir_loaded = catalog.source(source).model(
                        follower.model, skin=follower.skin
                    );
                    heir_resource = ModelResource(
                        name=heir_key, model=heir_loaded.model, skins=heir_loaded.skins
                    );
                    resources[heir_key] = heir_resource;
                    world +>:HasModelResource:+> heir_resource;
                }
                heir.visual = attach_model(heir, resources[heir_key]);
                heir.visual.offset = Vec3(z=-level.collision.eye_height);
                heir_frames = resources[heir_key].model.surfaces[0].frames;
                heir.idle_animation = frame_indices(
                    heir_frames, follower.idle_frames, follower.model, "idle"
                );
                heir.animation = frame_indices(
                    heir_frames, follower.run_frames, follower.model, "run"
                );
                heir.death_animation = frame_indices(
                    heir_frames, follower.death_frames, follower.model, "death"
                );
                heir.pain_animation = frame_indices(
                    heir_frames, follower.pain_frames, follower.model, "pain"
                );
                for variant in follower.pain_variants {
                    heir.pain_animations.append(
                        frame_indices(heir_frames, variant, follower.model, "pain")
                    );
                }
                for profile in heir.profiles {
                    heir.profile_animations.append(
                        frame_indices(heir_frames, profile.frames, follower.model, profile.name)
                    );
                }
                heir.modeled = True;
                heir.visual.visible = False;
                move_to_area(heir, level.areas[level.locate(position)]);
                world +>:HasOpponent:+> heir;
                count += 1;
            }
        }
    } finally {
        catalog.close();
    }
    return count;
}
